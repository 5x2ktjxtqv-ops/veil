import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let configuration: RuntimeConfiguration
    private let overlayInstanceLease: OverlayInstanceLease
    private let powerKeeper: BackgroundTaskPowerKeeper
    private let store = StatusStore()
    private lazy var telemetry = TelemetryService(
        mullvadApproval: configuration.mullvadApproval,
        cpuProvider: CPUUsageSampler(
            temperatureProvider: configuration.cpuTemperatureApproval.isApproved
                ? PowermetricsCPUTemperatureSampler()
                : UnavailableCPUTemperatureProvider()
        ),
        vpnProvider: MullvadMonitor(
            speedProbe: VPNPathSpeedProbe(configuration: configuration.vpnSpeedProbe)
        )
    )
    private lazy var modelGrowthClient = ModelGrowthCompactStatusClient(
        configuration: configuration.modelGrowthMonitor
    )
    private lazy var taskStatusClient = LocalTaskStatusFileClient(
        configuration: configuration.taskStatusMonitor
    )

    private var topFusionController: TopFusionBarController?
    private var hudController: OverlayHUDController?
    private var bottomCornerMaskController: BottomCornerMaskController?
    private var timer: Timer?
    private var taskStatusTimer: Timer?
    private var modelGrowthTimer: Timer?
    private var bottomCornerMaskTimer: Timer?
    private var powerKeepAliveVerificationTimer: Timer?
    private var thermalStateObserver: NSObjectProtocol?
    private var activeSpaceObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var isRefreshing = false
    private var refreshPending = false
    private var isRefreshingTaskStatus = false
    private var isRefreshingModelGrowth = false

    init(
        configuration: RuntimeConfiguration = RuntimeConfiguration.load(),
        overlayInstanceLease: OverlayInstanceLease,
        powerKeeper: BackgroundTaskPowerKeeper? = nil
    ) {
        self.configuration = configuration
        self.overlayInstanceLease = overlayInstanceLease
        self.powerKeeper = powerKeeper ?? BackgroundTaskPowerKeeper(configuration: configuration.powerKeepAlive)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if configuration.startupError != nil {
            return
        }

        if let mockTelemetry = configuration.mockTelemetry {
            store.snapshot = mockTelemetry.snapshot
        }
        #endif

        topFusionController = TopFusionBarController()
        hudController = OverlayHUDController(
            store: store,
            clickThrough: configuration.hudClickThrough,
            configuration: hudConfiguration
        )
        if configuration.bottomCornerMask.isEnabled {
            bottomCornerMaskController = BottomCornerMaskController(configuration: configuration.bottomCornerMask)
        }

        topFusionController?.show()
        hudController?.show()
        bottomCornerMaskController?.show()
        startPowerKeepAlive()
        startTaskStatusMonitor()
        startWakeRestore()
        startBottomCornerMaskVisibilityRefresh()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        if !configuration.shouldStartLiveTelemetry {
            return
        }

        startModelGrowthMonitor()
        startLiveTelemetry()
    }

    private func startLiveTelemetry() {
        refreshNow()
        thermalStateObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshNow(queueIfBusy: true)
            }
        }

        let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshNow()
            }
        }
        timer.tolerance = 1.0
        self.timer = timer

        if configuration.shouldPromptForMullvadApproval {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                requestMullvadApprovalForThisRun()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        taskStatusTimer?.invalidate()
        modelGrowthTimer?.invalidate()
        bottomCornerMaskTimer?.invalidate()
        powerKeepAliveVerificationTimer?.invalidate()
        powerKeeper.stop()
        if let thermalStateObserver {
            NotificationCenter.default.removeObserver(thermalStateObserver)
        }
        if let activeSpaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeSpaceObserver)
        }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    @objc private func screenParametersChanged() {
        topFusionController?.rebuild()
        hudController?.reposition()
        bottomCornerMaskController?.rebuild()
        bottomCornerMaskController?.refreshVisibility()
    }

    private func startPowerKeepAlive() {
        let status = powerKeeper.start()
        store.powerKeepAlive = powerKeeper.snapshot(from: status)
        reportPowerKeepAliveFailures(status)
        startPowerKeepAliveVerification()
    }

    private func startWakeRestore() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let status = self.powerKeeper.restart()
                self.store.powerKeepAlive = self.powerKeeper.snapshot(from: status)
                self.reportPowerKeepAliveFailures(status)
                self.screenParametersChanged()
                if self.configuration.shouldStartLiveTelemetry {
                    self.refreshTaskStatusNow()
                    self.refreshModelGrowthNow()
                    self.refreshNow(queueIfBusy: true)
                }
            }
        }
    }

    private func startPowerKeepAliveVerification() {
        powerKeepAliveVerificationTimer?.invalidate()

        let timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.store.powerKeepAlive = self.powerKeeper.verifyAndRepair()
            }
        }
        timer.tolerance = 5.0
        powerKeepAliveVerificationTimer = timer
    }

    private func reportPowerKeepAliveFailures(_ status: PowerKeepAliveStatus) {
        var messages: [String] = []

        let assertionFailures = status.failures
            .map { "\($0.kind.logName)=\($0.returnCode)" }
        messages.append(contentsOf: assertionFailures)

        let systemPolicyFailures: [String] = status.systemPolicyStatus?.failures.map { failure in
            let command = failure.arguments.isEmpty
                ? "pmset"
                : "pmset \(failure.arguments.joined(separator: " "))"
            return "\(failure.reason): \(command) \(failure.output)"
        } ?? []
        messages.append(contentsOf: systemPolicyFailures)

        guard !messages.isEmpty else { return }

        fputs("Veil power keepalive degraded: \(messages.joined(separator: "; "))\n", stderr)
    }

    private func startBottomCornerMaskVisibilityRefresh() {
        guard bottomCornerMaskController != nil else { return }

        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bottomCornerMaskController?.activeSpaceDidChange()
            }
        }

        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bottomCornerMaskController?.refreshVisibility()
            }
        }
        timer.tolerance = 0.15
        bottomCornerMaskTimer = timer
    }

    private var hudConfiguration: StatusHUDConfiguration {
        #if DEBUG
        if let mockTelemetry = configuration.mockTelemetry {
            return mockTelemetry.hudConfiguration
        }
        #endif

        return .productionCompact
            .withSignals(configuration.statusSignals.isEnabled)
    }

    private func startTaskStatusMonitor() {
        guard configuration.statusSignals.isEnabled,
              configuration.taskStatusMonitor.isEnabled else {
            return
        }

        refreshTaskStatusNow()

        let timer = Timer.scheduledTimer(
            withTimeInterval: configuration.taskStatusMonitor.pollIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshTaskStatusNow()
            }
        }
        timer.tolerance = min(max(configuration.taskStatusMonitor.pollIntervalSeconds * 0.2, 0.2), 1.0)
        taskStatusTimer = timer
    }

    private func refreshTaskStatusNow() {
        guard configuration.statusSignals.isEnabled,
              configuration.taskStatusMonitor.isEnabled,
              !isRefreshingTaskStatus else {
            return
        }

        isRefreshingTaskStatus = true

        Task { @MainActor [weak self] in
            guard let self else { return }

            let status = await self.taskStatusClient.fetch()
            self.store.taskStatus = status
            self.isRefreshingTaskStatus = false
        }
    }

    private func startModelGrowthMonitor() {
        guard configuration.modelGrowthMonitor.isEnabled else { return }

        store.modelGrowth = .unavailable(updatedAt: Date(), reason: "loading")
        refreshModelGrowthNow()
    }

    private func refreshModelGrowthNow() {
        guard configuration.modelGrowthMonitor.isEnabled else { return }
        guard !isRefreshingModelGrowth else { return }

        isRefreshingModelGrowth = true

        Task { @MainActor [weak self] in
            guard let self else { return }

            let status = await self.modelGrowthClient.fetch()
            self.store.modelGrowth = status
            self.isRefreshingModelGrowth = false
            self.scheduleModelGrowthRefresh(after: status.pollAfterSeconds)
        }
    }

    private func scheduleModelGrowthRefresh(after interval: TimeInterval) {
        modelGrowthTimer?.invalidate()

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshModelGrowthNow()
            }
        }
        timer.tolerance = min(max(interval * 0.2, 1.0), 5.0)
        modelGrowthTimer = timer
    }

    private func refreshNow(queueIfBusy: Bool = false) {
        guard !isRefreshing else {
            if queueIfBusy {
                refreshPending = true
            }
            return
        }

        isRefreshing = true

        telemetry.refresh { [weak self] snapshot in
            guard let self else { return }
            self.store.snapshot = snapshot
            self.isRefreshing = false

            if self.refreshPending {
                self.refreshPending = false
                self.refreshNow()
            }
        }
    }

    private func requestMullvadApprovalForThisRun() {
        let alert = NSAlert()
        alert.messageText = "Allow Veil to read Mullvad status?"
        alert.informativeText = """
        For this run, Veil can execute read-only checks: `mullvad status` about every 15 seconds and a short 3-packet `ping` to the current Mullvad relay or visible VPN endpoint about every 30 seconds. Veil displays the median packet latency.

        Veil will not connect, disconnect, reconnect, switch relays, change DNS, change tunnel settings, or modify Mullvad state.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Allow Read-Only")
        alert.addButton(withTitle: "Not Now")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Remember read-only approval"

        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .modalPanel
        let response = alert.runModal()
        let approval: MullvadReadApproval = response == .alertFirstButtonReturn ? .approved : .denied
        if approval.isApproved, alert.suppressionButton?.state == .on {
            MullvadReadApprovalPersistence.saveApproved()
        }
        telemetry.setMullvadApproval(approval)
        refreshNow(queueIfBusy: true)
    }
}
