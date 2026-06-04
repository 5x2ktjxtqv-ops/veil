import Foundation
import IOKit.pwr_mgt

enum PowerAssertionKind: CaseIterable, Equatable, Sendable {
    case preventUserIdleSystemSleep
    case preventDiskIdle
    case networkClientActive

    static let backgroundTaskSet: [PowerAssertionKind] = [
        .preventUserIdleSystemSleep,
        .preventDiskIdle,
        .networkClientActive
    ]

    var iokitAssertionType: NSString {
        switch self {
        case .preventUserIdleSystemSleep:
            return kIOPMAssertPreventUserIdleSystemSleep as NSString
        case .preventDiskIdle:
            return kIOPMAssertPreventDiskIdle as NSString
        case .networkClientActive:
            return kIOPMAssertNetworkClientActive as NSString
        }
    }

    var reason: String {
        switch self {
        case .preventUserIdleSystemSleep:
            return "Veil is keeping background model tasks, telemetry, and network sessions active."
        case .preventDiskIdle:
            return "Veil is keeping disk I/O responsive for background model tasks."
        case .networkClientActive:
            return "Veil is keeping network and VPN-dependent background tasks active."
        }
    }

    var logName: String {
        switch self {
        case .preventUserIdleSystemSleep:
            return "PreventUserIdleSystemSleep"
        case .preventDiskIdle:
            return "PreventDiskIdle"
        case .networkClientActive:
            return "NetworkClientActive"
        }
    }
}

struct PowerAssertionHandle: Equatable, Sendable {
    var kind: PowerAssertionKind
    var rawID: IOPMAssertionID
}

struct PowerAssertionFailure: Error, Equatable, Sendable {
    var kind: PowerAssertionKind
    var returnCode: Int32
}

struct PowerKeepAliveStatus: Equatable, Sendable {
    var isEnabled: Bool
    var activeAssertions: [PowerAssertionKind]
    var failures: [PowerAssertionFailure]
    var systemPolicyStatus: SystemPowerPolicyStatus?

    static let disabled = PowerKeepAliveStatus(
        isEnabled: false,
        activeAssertions: [],
        failures: [],
        systemPolicyStatus: nil
    )
}

protocol PowerAssertionManaging: Sendable {
    func createAssertion(kind: PowerAssertionKind, reason: String) -> Result<PowerAssertionHandle, PowerAssertionFailure>
    @discardableResult
    func releaseAssertion(_ handle: PowerAssertionHandle) -> Int32
}

struct SystemPowerAssertionManager: PowerAssertionManaging {
    func createAssertion(
        kind: PowerAssertionKind,
        reason: String
    ) -> Result<PowerAssertionHandle, PowerAssertionFailure> {
        var assertionID = IOPMAssertionID(kIOPMNullAssertionID)
        let result = IOPMAssertionCreateWithName(
            kind.iokitAssertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as NSString,
            &assertionID
        )

        guard result == kIOReturnSuccess else {
            return .failure(PowerAssertionFailure(kind: kind, returnCode: result))
        }

        return .success(PowerAssertionHandle(kind: kind, rawID: assertionID))
    }

    @discardableResult
    func releaseAssertion(_ handle: PowerAssertionHandle) -> Int32 {
        IOPMAssertionRelease(handle.rawID)
    }
}

final class BackgroundTaskPowerKeeper {
    private let configuration: PowerKeepAliveConfiguration
    private let manager: any PowerAssertionManaging
    private let systemPolicyManager: any SystemPowerPolicyManaging
    private var activeAssertions: [PowerAssertionKind: PowerAssertionHandle] = [:]
    private var isSystemPolicyActive = false

    init(
        configuration: PowerKeepAliveConfiguration,
        manager: any PowerAssertionManaging = SystemPowerAssertionManager(),
        systemPolicyManager: any SystemPowerPolicyManaging = PMSetSystemPowerPolicyManager()
    ) {
        self.configuration = configuration
        self.manager = manager
        self.systemPolicyManager = systemPolicyManager
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> PowerKeepAliveStatus {
        guard configuration.isEnabled else {
            return .disabled
        }

        var failures: [PowerAssertionFailure] = []
        for kind in PowerAssertionKind.backgroundTaskSet where activeAssertions[kind] == nil {
            switch manager.createAssertion(kind: kind, reason: kind.reason) {
            case .success(let handle):
                activeAssertions[kind] = handle
            case .failure(let failure):
                failures.append(failure)
            }
        }

        let systemPolicyStatus: SystemPowerPolicyStatus?
        switch configuration.systemPolicyMode {
        case .disabled:
            systemPolicyStatus = nil
        case .enabled:
            if isSystemPolicyActive {
                systemPolicyStatus = nil
            } else {
                systemPolicyStatus = systemPolicyManager.activate()
                if let systemPolicyStatus {
                    isSystemPolicyActive = !systemPolicyStatus.appliedSettings.isEmpty
                        || systemPolicyStatus.appliedDisableSleep
                }
            }
        }

        return PowerKeepAliveStatus(
            isEnabled: true,
            activeAssertions: PowerAssertionKind.backgroundTaskSet.filter { activeAssertions[$0] != nil },
            failures: failures,
            systemPolicyStatus: systemPolicyStatus
        )
    }

    func snapshot(from status: PowerKeepAliveStatus, checkedAt: Date = Date()) -> PowerKeepAliveSnapshot {
        runtimeSnapshot(
            activeAssertions: status.activeAssertions,
            failures: status.failures,
            systemPolicyStatus: status.systemPolicyStatus,
            checkedAt: checkedAt
        )
    }

    func verifyAndRepair(checkedAt: Date = Date()) -> PowerKeepAliveSnapshot {
        let verified = verify(checkedAt: checkedAt)
        guard shouldRepair(verified) else {
            return verified
        }

        return snapshot(from: restart(), checkedAt: checkedAt)
    }

    func restart() -> PowerKeepAliveStatus {
        stop()
        return start()
    }

    func stop() {
        if configuration.systemPolicyMode == .enabled, isSystemPolicyActive {
            _ = systemPolicyManager.restore()
            isSystemPolicyActive = false
        }

        for kind in PowerAssertionKind.backgroundTaskSet.reversed() {
            guard let handle = activeAssertions.removeValue(forKey: kind) else { continue }
            manager.releaseAssertion(handle)
        }
    }

    private func verify(checkedAt: Date) -> PowerKeepAliveSnapshot {
        let activeAssertions = PowerAssertionKind.backgroundTaskSet.filter { self.activeAssertions[$0] != nil }
        let systemPolicyStatus: SystemPowerPolicyStatus?

        switch configuration.systemPolicyMode {
        case .disabled:
            systemPolicyStatus = nil
        case .enabled:
            systemPolicyStatus = isSystemPolicyActive ? systemPolicyManager.verify() : nil
        }

        return runtimeSnapshot(
            activeAssertions: activeAssertions,
            failures: [],
            systemPolicyStatus: systemPolicyStatus,
            checkedAt: checkedAt
        )
    }

    private func runtimeSnapshot(
        activeAssertions: [PowerAssertionKind],
        failures: [PowerAssertionFailure],
        systemPolicyStatus: SystemPowerPolicyStatus?,
        checkedAt: Date
    ) -> PowerKeepAliveSnapshot {
        guard configuration.isEnabled else {
            return .inactive
        }

        let mode: PowerKeepAliveMode = configuration.systemPolicyMode == .enabled
            ? .systemPolicy
            : .assertions
        let state = powerKeepAliveState(
            mode: mode,
            activeAssertions: activeAssertions,
            failures: failures,
            systemPolicyStatus: systemPolicyStatus
        )

        return PowerKeepAliveSnapshot(
            mode: mode,
            state: state,
            activeAssertions: activeAssertions,
            systemPolicyStatus: systemPolicyStatus,
            checkedAt: checkedAt
        )
    }

    private func powerKeepAliveState(
        mode: PowerKeepAliveMode,
        activeAssertions: [PowerAssertionKind],
        failures: [PowerAssertionFailure],
        systemPolicyStatus: SystemPowerPolicyStatus?
    ) -> PowerKeepAliveState {
        let expectedAssertions = Set(PowerAssertionKind.backgroundTaskSet)
        let activeAssertionSet = Set(activeAssertions)
        let assertionsComplete = activeAssertionSet == expectedAssertions && failures.isEmpty

        guard mode == .systemPolicy else {
            if assertionsComplete {
                return .asserted
            }

            return activeAssertions.isEmpty ? .failed : .degraded
        }

        guard let systemPolicyStatus else {
            return assertionsComplete ? .degraded : .failed
        }

        if assertionsComplete, systemPolicyStatus.isActive {
            return .verified
        }

        if systemPolicyStatus.failures.contains(where: { $0.reason == .requiresRoot || $0.reason == .snapshotUnavailable })
            && systemPolicyStatus.appliedSettings.isEmpty
            && !systemPolicyStatus.appliedDisableSleep {
            return .failed
        }

        if assertionsComplete || !systemPolicyStatus.appliedSettings.isEmpty || systemPolicyStatus.appliedDisableSleep {
            return .degraded
        }

        return .failed
    }

    private func shouldRepair(_ snapshot: PowerKeepAliveSnapshot) -> Bool {
        guard configuration.isEnabled else { return false }

        let expectedAssertions = Set(PowerAssertionKind.backgroundTaskSet)
        if Set(snapshot.activeAssertions) != expectedAssertions {
            return true
        }

        guard snapshot.mode == .systemPolicy else {
            return snapshot.state == .failed
        }

        let repairableSystemFailures: Set<SystemPowerPolicyFailureReason> = [
            .snapshotUnavailable,
            .verificationFailed
        ]

        return snapshot.systemPolicyStatus?.failures.contains {
            repairableSystemFailures.contains($0.reason)
        } ?? false
    }
}
