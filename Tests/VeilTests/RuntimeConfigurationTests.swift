import Foundation
import XCTest
@testable import Veil

final class RuntimeConfigurationTests: XCTestCase {
    func testDefaultConfigurationKeepsPersonalSignalsOptIn() {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["Veil"]
        )

        XCTAssertTrue(configuration.hudClickThrough)
        XCTAssertFalse(configuration.powerKeepAlive.isEnabled)
        XCTAssertEqual(configuration.powerKeepAlive.systemPolicyMode, .disabled)
        XCTAssertFalse(configuration.taskStatusMonitor.isEnabled)
        XCTAssertFalse(configuration.statusSignals.isEnabled)
        XCTAssertFalse(configuration.modelGrowthMonitor.isEnabled)
        XCTAssertEqual(configuration.modelGrowthMonitor.endpoint, ModelGrowthMonitorConfiguration.defaultEndpoint)
        XCTAssertFalse(configuration.vpnSpeedProbe.isEnabled)
        XCTAssertEqual(configuration.vpnSpeedProbe.downloadEndpoint, VPNSpeedProbeConfiguration.defaultDownloadEndpoint)
        XCTAssertEqual(configuration.vpnSpeedProbe.intervalSeconds, VPNSpeedProbeConfiguration.defaultIntervalSeconds)
        XCTAssertEqual(configuration.mullvadApproval, .notRequested)
        XCTAssertFalse(configuration.shouldPromptForMullvadApproval)
        XCTAssertFalse(configuration.shouldStartLiveTelemetry)
    }

    func testStatusSignalsCanBeEnabledForLocalSignalHUD() {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["Veil", "--status-signals"]
        )

        XCTAssertTrue(configuration.statusSignals.isEnabled)
        XCTAssertTrue(configuration.shouldStartLiveTelemetry)
    }

    func testMullvadApprovalPromptCanBeRequestedForInteractiveRuns() {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["Veil", "--prompt-mullvad-approval"]
        )

        XCTAssertEqual(configuration.mullvadApproval, .notRequested)
        XCTAssertTrue(configuration.shouldPromptForMullvadApproval)
        XCTAssertTrue(configuration.statusSignals.isEnabled)
        XCTAssertTrue(configuration.shouldStartLiveTelemetry)
    }

    func testExplicitApprovalSkipsPromptForThisRun() {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["Veil", "--approve-mullvad-readonly"]
        )

        XCTAssertEqual(configuration.mullvadApproval, .approved)
        XCTAssertFalse(configuration.shouldPromptForMullvadApproval)
        XCTAssertTrue(configuration.statusSignals.isEnabled)
        XCTAssertTrue(configuration.shouldStartLiveTelemetry)
    }

    func testExplicitDenialSkipsPromptAndKeepsReadsDisabled() {
        let configuration = RuntimeConfiguration.load(
            environment: ["VEIL_DISABLE_MULLVAD_READS": "1"],
            arguments: ["Veil"]
        )

        XCTAssertEqual(configuration.mullvadApproval, .denied)
        XCTAssertFalse(configuration.shouldPromptForMullvadApproval)
        XCTAssertFalse(configuration.statusSignals.isEnabled)
        XCTAssertFalse(configuration.shouldStartLiveTelemetry)
    }

    func testMullvadReadDenialWinsConflictingSignals() {
        let configuration = RuntimeConfiguration.load(
            environment: [
                "VEIL_APPROVE_MULLVAD_READS": "1",
                "VEIL_DISABLE_MULLVAD_READS": "1"
            ],
            arguments: ["Veil", "--approve-mullvad-readonly"]
        )

        XCTAssertEqual(configuration.mullvadApproval, .denied)
        XCTAssertFalse(configuration.shouldPromptForMullvadApproval)
    }

    func testPersistedMullvadApprovalSkipsPromptAndApprovesReads() {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["Veil"],
            persistedMullvadApproval: .approved
        )

        XCTAssertEqual(configuration.mullvadApproval, .approved)
        XCTAssertFalse(configuration.shouldPromptForMullvadApproval)
        XCTAssertTrue(configuration.statusSignals.isEnabled)
        XCTAssertTrue(configuration.shouldStartLiveTelemetry)
    }

    func testExplicitMullvadDenialWinsPersistedApproval() {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["Veil", "--deny-mullvad-readonly"],
            persistedMullvadApproval: .approved
        )

        XCTAssertEqual(configuration.mullvadApproval, .denied)
        XCTAssertFalse(configuration.shouldPromptForMullvadApproval)
    }

    func testPersistedMullvadApprovalCanBeStoredAndCleared() throws {
        let suiteName = "dev.veil.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        XCTAssertNil(MullvadReadApprovalPersistence.load(defaults: defaults))

        MullvadReadApprovalPersistence.saveApproved(defaults: defaults)
        XCTAssertEqual(MullvadReadApprovalPersistence.load(defaults: defaults), .approved)

        MullvadReadApprovalPersistence.clear(defaults: defaults)
        XCTAssertNil(MullvadReadApprovalPersistence.load(defaults: defaults))
    }

    func testCPUTemperatureReadsDefaultToNotRequested() {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["Veil"]
        )

        XCTAssertEqual(configuration.cpuTemperatureApproval, .notRequested)
    }

    func testCPUTemperatureReadApprovalParsesExplicitFlag() {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["Veil", "--approve-cpu-temperature-readonly"]
        )

        XCTAssertEqual(configuration.cpuTemperatureApproval, .approved)
        XCTAssertTrue(configuration.statusSignals.isEnabled)
        XCTAssertTrue(configuration.shouldStartLiveTelemetry)
    }

    func testCPUTemperatureReadDenialParsesEnvironment() {
        let configuration = RuntimeConfiguration.load(
            environment: ["VEIL_DISABLE_CPU_TEMPERATURE_READS": "1"],
            arguments: ["Veil"]
        )

        XCTAssertEqual(configuration.cpuTemperatureApproval, .denied)
    }

    func testCPUTemperatureReadDenialWinsConflictingSignals() {
        let configuration = RuntimeConfiguration.load(
            environment: [
                "VEIL_APPROVE_CPU_TEMPERATURE_READS": "1",
                "VEIL_DISABLE_CPU_TEMPERATURE_READS": "1"
            ],
            arguments: ["Veil", "--approve-cpu-temperature-readonly"]
        )

        XCTAssertEqual(configuration.cpuTemperatureApproval, .denied)
    }

    func testClickThroughCanBeDisabledForLocalRuns() {
        let configuration = RuntimeConfiguration.load(
            environment: ["VEIL_CLICK_THROUGH": "0"],
            arguments: ["Veil"]
        )

        XCTAssertFalse(configuration.hudClickThrough)
    }

    func testBottomCornerMaskDefaultsToEnabled() {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["Veil"]
        )

        XCTAssertTrue(configuration.bottomCornerMask.isEnabled)
        XCTAssertEqual(BottomCornerMaskConfiguration.defaultRadius, 21.2, accuracy: 0.001)
        XCTAssertEqual(configuration.bottomCornerMask.radius, BottomCornerMaskConfiguration.defaultRadius)
    }

    func testBottomCornerMaskCanBeDisabledByEnvironment() {
        let configuration = RuntimeConfiguration.load(
            environment: ["VEIL_BOTTOM_CORNER_MASK": "0"],
            arguments: ["Veil"]
        )

        XCTAssertFalse(configuration.bottomCornerMask.isEnabled)
    }

    func testBottomCornerMaskCanBeDisabledByArgument() {
        let configuration = RuntimeConfiguration.load(
            environment: ["VEIL_BOTTOM_CORNER_MASK": "1"],
            arguments: ["Veil", "--no-bottom-corner-mask"]
        )

        XCTAssertFalse(configuration.bottomCornerMask.isEnabled)
    }

    func testBottomCornerMaskParsesPrototypeEnvironment() {
        let configuration = RuntimeConfiguration.load(
            environment: [
                "VEIL_BOTTOM_CORNER_MASK": "1",
                "VEIL_BOTTOM_CORNER_RADIUS": "24"
            ],
            arguments: ["Veil"]
        )

        XCTAssertTrue(configuration.bottomCornerMask.isEnabled)
        XCTAssertEqual(configuration.bottomCornerMask.radius, 24)
    }

    func testBottomCornerMaskRadiusIsClamped() {
        let small = RuntimeConfiguration.load(
            environment: [
                "VEIL_BOTTOM_CORNER_MASK": "1",
                "VEIL_BOTTOM_CORNER_RADIUS": "2"
            ],
            arguments: ["Veil"]
        )
        let large = RuntimeConfiguration.load(
            environment: [
                "VEIL_BOTTOM_CORNER_MASK": "1",
                "VEIL_BOTTOM_CORNER_RADIUS": "240"
            ],
            arguments: ["Veil"]
        )

        XCTAssertEqual(small.bottomCornerMask.radius, BottomCornerMaskConfiguration.minimumRadius)
        XCTAssertEqual(large.bottomCornerMask.radius, BottomCornerMaskConfiguration.maximumRadius)
    }

    func testPowerKeepAliveCanBeDisabledByEnvironment() {
        let configuration = RuntimeConfiguration.load(
            environment: ["VEIL_POWER_KEEPALIVE": "0"],
            arguments: ["Veil"]
        )

        XCTAssertFalse(configuration.powerKeepAlive.isEnabled)
        XCTAssertEqual(configuration.powerKeepAlive.systemPolicyMode, .disabled)
    }

    func testPowerKeepAliveCanBeDisabledByArgument() {
        let configuration = RuntimeConfiguration.load(
            environment: ["VEIL_POWER_KEEPALIVE": "1"],
            arguments: ["Veil", "--no-power-keepalive"]
        )

        XCTAssertFalse(configuration.powerKeepAlive.isEnabled)
        XCTAssertEqual(configuration.powerKeepAlive.systemPolicyMode, .disabled)
    }

    func testPowerKeepAliveArgumentCanOverrideDisabledEnvironment() {
        let configuration = RuntimeConfiguration.load(
            environment: ["VEIL_POWER_KEEPALIVE": "0"],
            arguments: ["Veil", "--power-keepalive"]
        )

        XCTAssertTrue(configuration.powerKeepAlive.isEnabled)
        XCTAssertEqual(configuration.powerKeepAlive.systemPolicyMode, .disabled)
    }

    func testLongRunEnablesProcessLifetimePowerKeepAlive() {
        let configuration = RuntimeConfiguration.load(
            environment: ["VEIL_POWER_KEEPALIVE": "0"],
            arguments: ["Veil", "--long-run"]
        )

        XCTAssertTrue(configuration.powerKeepAlive.isEnabled)
        XCTAssertEqual(configuration.powerKeepAlive.systemPolicyMode, .disabled)
    }

    func testLongRunCanBeEnabledByEnvironment() {
        let configuration = RuntimeConfiguration.load(
            environment: ["VEIL_LONG_RUN": "1"],
            arguments: ["Veil"]
        )

        XCTAssertTrue(configuration.powerKeepAlive.isEnabled)
        XCTAssertEqual(configuration.powerKeepAlive.systemPolicyMode, .disabled)
    }

    func testSystemPowerKeepAliveEnablesPowerKeepAliveAndSystemPolicyMode() {
        let configuration = RuntimeConfiguration.load(
            environment: ["VEIL_POWER_KEEPALIVE": "0"],
            arguments: ["Veil", "--system-power-keepalive"]
        )

        XCTAssertTrue(configuration.powerKeepAlive.isEnabled)
        XCTAssertEqual(configuration.powerKeepAlive.systemPolicyMode, .enabled)
    }

    func testNoPowerKeepAliveDisablesSystemPowerKeepAlive() {
        let configuration = RuntimeConfiguration.load(
            environment: ["VEIL_SYSTEM_POWER_KEEPALIVE": "1"],
            arguments: ["Veil", "--no-power-keepalive"]
        )

        XCTAssertFalse(configuration.powerKeepAlive.isEnabled)
        XCTAssertEqual(configuration.powerKeepAlive.systemPolicyMode, .disabled)
    }

    func testModelGrowthMonitorCanBeDisabledByArgument() {
        let configuration = RuntimeConfiguration.load(
            environment: ["VEIL_MODEL_GROWTH_MONITOR": "1"],
            arguments: ["Veil", "--no-model-growth-monitor"]
        )

        XCTAssertFalse(configuration.modelGrowthMonitor.isEnabled)
    }

    func testTaskStatusFileEnablesStatusSignals() throws {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: [
                "Veil",
                "--task-status-file",
                "~/Library/Application Support/Veil/task.json",
                "--task-status-poll-seconds",
                "0.25",
                "--task-status-stale-seconds",
                "5"
            ]
        )

        XCTAssertTrue(configuration.taskStatusMonitor.isEnabled)
        XCTAssertTrue(configuration.statusSignals.isEnabled)
        XCTAssertTrue(configuration.shouldStartLiveTelemetry)
        XCTAssertTrue(configuration.taskStatusMonitor.fileURL.isFileURL)
        XCTAssertTrue(configuration.taskStatusMonitor.fileURL.path.hasSuffix("/Library/Application Support/Veil/task.json"))
        XCTAssertEqual(configuration.taskStatusMonitor.pollIntervalSeconds, 1)
        XCTAssertEqual(configuration.taskStatusMonitor.staleAfterSeconds, 30)
    }

    func testTaskStatusCanBeDisabledByArgument() {
        let configuration = RuntimeConfiguration.load(
            environment: ["VEIL_TASK_STATUS_FILE": "/tmp/veil-task.json"],
            arguments: ["Veil", "--no-task-status"]
        )

        XCTAssertFalse(configuration.taskStatusMonitor.isEnabled)
        XCTAssertFalse(configuration.statusSignals.isEnabled)
        XCTAssertFalse(configuration.shouldStartLiveTelemetry)
    }

    func testModelGrowthMonitorParsesEndpoint() throws {
        let configuration = RuntimeConfiguration.load(
            environment: [
                "VEIL_MODEL_GROWTH_MONITOR": "1",
                "VEIL_MODEL_GROWTH_URL": "http://127.0.0.1:9999/v1/model-growth/compact-status"
            ],
            arguments: ["Veil"]
        )

        XCTAssertTrue(configuration.modelGrowthMonitor.isEnabled)
        XCTAssertTrue(configuration.statusSignals.isEnabled)
        XCTAssertTrue(configuration.shouldStartLiveTelemetry)
        XCTAssertEqual(
            configuration.modelGrowthMonitor.endpoint,
            try XCTUnwrap(URL(string: "http://127.0.0.1:9999/v1/model-growth/compact-status"))
        )
    }

    func testModelGrowthMonitorRewritesPrivateStatusEndpointToCompactStatus() throws {
        let configuration = RuntimeConfiguration.load(
            environment: [
                "VEIL_MODEL_GROWTH_MONITOR": "1",
                "VEIL_MODEL_GROWTH_URL": "http://127.0.0.1:8765/v1/model-growth/status"
            ],
            arguments: ["Veil"]
        )

        XCTAssertEqual(
            configuration.modelGrowthMonitor.endpoint,
            try XCTUnwrap(URL(string: "http://127.0.0.1:8765/v1/model-growth/compact-status"))
        )
    }

    func testModelGrowthMonitorDoesNotEnableFromPrivateServiceTokenAlias() {
        let configuration = RuntimeConfiguration.load(
            environment: ["PRIVATE_SERVICE_TOKEN": "private-token"],
            arguments: ["Veil"]
        )

        XCTAssertFalse(configuration.modelGrowthMonitor.isEnabled)
        XCTAssertFalse(configuration.statusSignals.isEnabled)
    }

    func testVPNSpeedProbeCanBeEnabledAndConfigured() throws {
        let configuration = RuntimeConfiguration.load(
            environment: [
                "VEIL_VPN_PROBE_INTERVAL_SECONDS": "600",
                "VEIL_VPN_PROBE_TIMEOUT_SECONDS": "4.5",
                "VEIL_VPN_PROBE_MAX_BYTES": "65536"
            ],
            arguments: [
                "Veil",
                "--vpn-speed-probe",
                "--vpn-speed-probe-url",
                "https://example.com/probe.bin",
                "--vpn-speed-probe-latency-url=https://example.com/generate_204",
                "--vpn-speed-probe-initial-delay-seconds",
                "3"
            ]
        )

        XCTAssertTrue(configuration.vpnSpeedProbe.isEnabled)
        XCTAssertTrue(configuration.statusSignals.isEnabled)
        XCTAssertTrue(configuration.shouldStartLiveTelemetry)
        XCTAssertEqual(
            configuration.vpnSpeedProbe.downloadEndpoint,
            try XCTUnwrap(URL(string: "https://example.com/probe.bin"))
        )
        XCTAssertEqual(
            configuration.vpnSpeedProbe.latencyEndpoint,
            try XCTUnwrap(URL(string: "https://example.com/generate_204"))
        )
        XCTAssertEqual(configuration.vpnSpeedProbe.intervalSeconds, 600)
        XCTAssertEqual(configuration.vpnSpeedProbe.initialDelaySeconds, 3)
        XCTAssertEqual(configuration.vpnSpeedProbe.timeoutSeconds, 4.5)
        XCTAssertEqual(configuration.vpnSpeedProbe.maxDownloadBytes, 65_536)
    }

    func testVPNSpeedProbeCanBeDisabledByArgument() {
        let configuration = RuntimeConfiguration.load(
            environment: ["VEIL_VPN_SPEED_PROBE": "1"],
            arguments: ["Veil", "--no-vpn-speed-probe"]
        )

        XCTAssertFalse(configuration.vpnSpeedProbe.isEnabled)
    }

    func testNoStatusSignalsForcesAdaptersOutOfLiveTelemetry() {
        let configuration = RuntimeConfiguration.load(
            environment: [
                "VEIL_STATUS_SIGNALS": "1",
                "VEIL_MODEL_GROWTH_MONITOR": "1"
            ],
            arguments: ["Veil", "--no-status-signals", "--prompt-mullvad-approval"]
        )

        XCTAssertFalse(configuration.statusSignals.isEnabled)
        XCTAssertTrue(configuration.modelGrowthMonitor.isEnabled)
        XCTAssertFalse(configuration.shouldPromptForMullvadApproval)
        XCTAssertFalse(configuration.shouldStartLiveTelemetry)
    }

    #if DEBUG
    func testMockTelemetryArgumentSelectsFixtureAndSkipsPrompt() {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["Veil", "--mock-telemetry", "defaultCompact"]
        )

        XCTAssertEqual(configuration.mockTelemetry?.fixture, .defaultCompact)
        XCTAssertTrue(configuration.statusSignals.isEnabled)
        XCTAssertFalse(configuration.shouldPromptForMullvadApproval)
        XCTAssertFalse(configuration.shouldStartLiveTelemetry)
        XCTAssertNil(configuration.startupError)
    }

    func testMockTelemetryAndLiveTelemetryAreMutuallyExclusive() {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["Veil", "--mock-telemetry", "defaultCompact", "--approve-mullvad-readonly"]
        )

        XCTAssertEqual(configuration.mockTelemetry?.fixture, .defaultCompact)
        XCTAssertEqual(configuration.mullvadApproval, .approved)
        XCTAssertFalse(configuration.shouldPromptForMullvadApproval)
        XCTAssertFalse(configuration.shouldStartLiveTelemetry)
    }

    func testMockTelemetryDefaultsToDefaultCompactWhenFixtureIsOmitted() {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["Veil", "--mock-telemetry", "--no-mullvad-approval-prompt"]
        )

        XCTAssertEqual(configuration.mockTelemetry?.fixture, .defaultCompact)
        XCTAssertFalse(configuration.shouldPromptForMullvadApproval)
        XCTAssertFalse(configuration.shouldStartLiveTelemetry)
        XCTAssertNil(configuration.startupError)
    }

    func testMockTelemetryCPUUnavailableFixtureParses() {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["Veil", "--mock-telemetry", "cpuTemperatureUnavailable"]
        )

        XCTAssertEqual(configuration.mockTelemetry?.fixture, .cpuTemperatureUnavailable)
        XCTAssertFalse(configuration.shouldStartLiveTelemetry)
        XCTAssertNil(configuration.startupError)
    }

    func testMockTelemetryModelGrowthFixtureParses() {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["Veil", "--mock-telemetry", "modelGrowthCompact"]
        )

        XCTAssertEqual(configuration.mockTelemetry?.fixture, .modelGrowthCompact)
        XCTAssertFalse(configuration.shouldStartLiveTelemetry)
        XCTAssertNil(configuration.startupError)
    }

    func testUnknownMockTelemetryFixtureFailsClosed() {
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["Veil", "--mock-telemetry", "missingFixture"]
        )

        XCTAssertNil(configuration.mockTelemetry)
        XCTAssertNotNil(configuration.startupError)
        XCTAssertFalse(configuration.shouldPromptForMullvadApproval)
        XCTAssertFalse(configuration.shouldStartLiveTelemetry)
    }
    #endif
}
