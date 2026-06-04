import XCTest
@testable import Veil

final class MullvadMonitorTests: XCTestCase {
    func testSampleWithoutApprovalReturnsFallbackWithoutStatusRead() {
        let runner = RecordingProcessRunner()
        let monitor = MullvadMonitor(processRunner: runner)

        let status = monitor.sample(downloadMbps: 12.4, approval: .notRequested)

        XCTAssertEqual(status.connection, .error)
        XCTAssertEqual(status.errorReason, .approvalRequired)
        XCTAssertEqual(status.stability, .approvalRequired)
        XCTAssertEqual(status.nodeHealth, .unknown)
        XCTAssertEqual(status.downloadMbps, 12.4)
        XCTAssertNil(status.latencyMs)
        XCTAssertTrue(runner.recordedCalls().isEmpty)
    }

    func testDeniedApprovalReturnsDeniedFallback() {
        let runner = RecordingProcessRunner()
        let monitor = MullvadMonitor(processRunner: runner)

        let status = monitor.sample(downloadMbps: nil, approval: .denied)

        XCTAssertEqual(status.connection, .error)
        XCTAssertEqual(status.errorReason, .approvalDenied)
        XCTAssertEqual(status.stability, .approvalDenied)
        XCTAssertEqual(status.nodeHealth, .unknown)
        XCTAssertTrue(runner.recordedCalls().isEmpty)
    }

    func testApprovedSampleUsesInjectedRunnerForStatusRead() {
        let runner = RecordingProcessRunner { _, _, _ in "Disconnected" }
        let monitor = MullvadMonitor(processRunner: runner)

        let status = monitor.sample(downloadMbps: nil, approval: .approved)
        let calls = runner.recordedCalls()

        XCTAssertEqual(status.connection, .disconnected)
        XCTAssertEqual(status.stability, .disconnected)
        XCTAssertEqual(calls.map(\.executable), ["/usr/bin/env"])
        XCTAssertEqual(calls.first?.arguments, ["mullvad", "status"])
    }

    func testApprovedStatusTimeoutReturnsTimeoutReason() {
        let runner = TimedOutProcessRunner()
        let monitor = MullvadMonitor(processRunner: runner)

        let status = monitor.sample(downloadMbps: nil, approval: .approved)

        XCTAssertEqual(status.connection, .error)
        XCTAssertEqual(status.errorReason, .timeout)
        XCTAssertEqual(status.stability, .cliUnavailableOrError)
        XCTAssertEqual(runner.recordedCalls().map(\.executable), ["/usr/bin/env"])
    }

    func testApprovedConnectedSampleUsesInjectedRunnerForLatencyProbe() {
        let runner = RecordingProcessRunner { executable, _, _ in
            if executable == "/usr/bin/env" {
                return """
                Connected
                Relay: de-fra-wg-001
                Visible location: Germany, Frankfurt.
                """
            }

            if executable == "/sbin/ping" {
                return "round-trip min/avg/max/stddev = 10.0/23.4/50.0/3.2 ms"
            }

            return nil
        }
        let monitor = MullvadMonitor(processRunner: runner)

        let status = monitor.sample(downloadMbps: nil, approval: .approved)
        let calls = runner.recordedCalls()

        XCTAssertEqual(status.connection, .connected)
        XCTAssertEqual(status.stability, .connectedHealthy)
        XCTAssertEqual(status.latencyMs, 23.4)
        XCTAssertEqual(calls.map(\.executable), ["/usr/bin/env", "/sbin/ping"])
        XCTAssertEqual(calls.last?.arguments, ["-n", "-c", "3", "de-fra-wg-001.relays.mullvad.net"])
    }

    func testFailedLatencyProbeDoesNotDegradeConnectedRelay() {
        let runner = RecordingProcessRunner { executable, _, _ in
            if executable == "/usr/bin/env" {
                return """
                Connected
                Relay: de-fra-wg-001
                Visible location: Germany, Frankfurt.
                """
            }

            return nil
        }
        let monitor = MullvadMonitor(processRunner: runner)

        let status = monitor.sample(downloadMbps: nil, approval: .approved)
        let calls = runner.recordedCalls()

        XCTAssertEqual(status.connection, .connected)
        XCTAssertNil(status.latencyMs)
        XCTAssertEqual(status.nodeHealth, .normal)
        XCTAssertEqual(status.stability, .connectedHealthy)
        XCTAssertEqual(calls.map(\.executable), ["/usr/bin/env", "/sbin/ping"])
    }

    func testApprovedConnectedSampleUsesPathSpeedProbeForEffectiveDownload() {
        let runner = RecordingProcessRunner { executable, _, _ in
            if executable == "/usr/bin/env" {
                return """
                Connected
                Relay: de-fra-wg-001
                Visible location: Germany, Frankfurt.
                """
            }

            if executable == "/sbin/ping" {
                return "round-trip min/avg/max/stddev = 10.0/23.4/50.0/3.2 ms"
            }

            return nil
        }
        let probe = StaticVPNPathSpeedProbe(
            result: .measured(
                downloadMbps: 9.2,
                source: .activeProbe,
                measuredAt: Date(timeIntervalSince1970: 0)
            )
        )
        let monitor = MullvadMonitor(processRunner: runner, speedProbe: probe)

        let status = monitor.sample(downloadMbps: 0.3, approval: .approved)
        let samples = probe.recordedSamples()

        XCTAssertEqual(status.connection, .connected)
        XCTAssertEqual(status.downloadMbps, 9.2)
        XCTAssertEqual(status.pathSpeed.source, .activeProbe)
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.passiveDownloadMbps, 0.3)
        XCTAssertEqual(samples.first?.relayIdentifier, "de-fra-wg-001")
    }

    func testApprovedLatencyProbeUsesMedianPacketTimeWhenSamplesIncludeSpike() {
        let runner = RecordingProcessRunner { executable, _, _ in
            if executable == "/usr/bin/env" {
                return """
                Connected
                Relay: de-fra-wg-001
                Visible location: Germany, Frankfurt.
                """
            }

            if executable == "/sbin/ping" {
                return """
                64 bytes from 10.0.0.1: icmp_seq=0 ttl=50 time=290.7 ms
                64 bytes from 10.0.0.1: icmp_seq=1 ttl=50 time=452.9 ms
                64 bytes from 10.0.0.1: icmp_seq=2 ttl=50 time=294.6 ms
                round-trip min/avg/max/stddev = 290.7/346.1/452.9/75.6 ms
                """
            }

            return nil
        }
        let monitor = MullvadMonitor(processRunner: runner)

        let status = monitor.sample(downloadMbps: nil, approval: .approved)

        XCTAssertEqual(status.latencyMs, 294.6)
        XCTAssertEqual(status.nodeHealth, .normal)
        XCTAssertEqual(status.stability, .connectedHealthy)
    }

    func testApprovedConciseConnectedStatusUsesExitRelayForLatencyProbe() {
        let runner = RecordingProcessRunner { executable, _, _ in
            if executable == "/usr/bin/env" {
                return "Connected to se-mma-wg-001 in Malmo, Sweden via dk-cph-wg-001"
            }

            if executable == "/sbin/ping" {
                return "round-trip min/avg/max/stddev = 10.0/23.4/50.0/3.2 ms"
            }

            return nil
        }
        let monitor = MullvadMonitor(processRunner: runner)

        let status = monitor.sample(downloadMbps: nil, approval: .approved)
        let calls = runner.recordedCalls()

        XCTAssertEqual(status.connection, .connected)
        XCTAssertEqual(status.countryCode, "SE")
        XCTAssertEqual(status.cityCode, "MMA")
        XCTAssertEqual(status.relayName, "se-mma-wg-001")
        XCTAssertEqual(status.visibleLocation, "Sweden, Malmo.")
        XCTAssertEqual(status.latencyMs, 23.4)
        XCTAssertEqual(status.stability, .connectedHealthy)
        XCTAssertEqual(calls.map(\.executable), ["/usr/bin/env", "/sbin/ping"])
        XCTAssertEqual(calls.last?.arguments, ["-n", "-c", "3", "se-mma-wg-001.relays.mullvad.net"])
    }

    func testApprovedVerboseMultihopStatusProbesExitRelayOnly() {
        let runner = RecordingProcessRunner { executable, _, _ in
            if executable == "/usr/bin/env" {
                return """
                Connected
                Relay: se-got-wg-001 via dk-cph-wg-001
                Features: Multihop
                Visible location: Sweden, Gothenburg. IPv4: 10.20.30.40
                """
            }

            if executable == "/sbin/ping" {
                return "round-trip min/avg/max/stddev = 10.0/23.4/50.0/3.2 ms"
            }

            return nil
        }
        let monitor = MullvadMonitor(processRunner: runner)

        let status = monitor.sample(downloadMbps: nil, approval: .approved)
        let pingCalls = runner.recordedCalls().filter { $0.executable == "/sbin/ping" }

        XCTAssertEqual(status.relayName, "se-got-wg-001")
        XCTAssertEqual(status.countryCode, "SE")
        XCTAssertEqual(status.cityCode, "GOT")
        XCTAssertEqual(status.latencyMs, 23.4)
        XCTAssertEqual(pingCalls.map(\.arguments), [
            ["-n", "-c", "3", "se-got-wg-001.relays.mullvad.net"]
        ])
    }

    func testApprovedConnectedStatusWithoutRelayUsesVisibleIPv4ForLatencyProbe() {
        let runner = RecordingProcessRunner { executable, _, _ in
            if executable == "/usr/bin/env" {
                return """
                Connected
                Visible location: Germany, Frankfurt. IPv4: 10.20.30.40
                """
            }

            if executable == "/sbin/ping" {
                return "round-trip min/avg/max/stddev = 10.0/23.4/50.0/3.2 ms"
            }

            return nil
        }
        let monitor = MullvadMonitor(processRunner: runner)

        let status = monitor.sample(downloadMbps: nil, approval: .approved)
        let pingCalls = runner.recordedCalls().filter { $0.executable == "/sbin/ping" }

        XCTAssertEqual(status.connection, .connected)
        XCTAssertNil(status.relayName)
        XCTAssertEqual(status.cityCode, "FRA")
        XCTAssertEqual(status.latencyMs, 23.4)
        XCTAssertEqual(status.nodeHealth, .normal)
        XCTAssertEqual(pingCalls.map(\.arguments), [
            ["-n", "-c", "3", "10.20.30.40"]
        ])
    }

    func testApprovedConnectedStatusIgnoresInvalidVisibleIPv4() {
        let runner = RecordingProcessRunner { executable, _, _ in
            if executable == "/usr/bin/env" {
                return """
                Connected
                Visible location: Germany, Frankfurt. IPv4: 999.20.30.40
                """
            }

            return nil
        }
        let monitor = MullvadMonitor(processRunner: runner)

        let status = monitor.sample(downloadMbps: nil, approval: .approved)
        let pingCalls = runner.recordedCalls().filter { $0.executable == "/sbin/ping" }

        XCTAssertEqual(status.connection, .connected)
        XCTAssertNil(status.latencyMs)
        XCTAssertEqual(status.nodeHealth, .unknown)
        XCTAssertTrue(pingCalls.isEmpty)
    }

    func testRelayChangeClearsCachedLatencyAndProbesNewRelay() {
        let runner = SequenceProcessRunner(
            statusOutputs: [
                """
                Connected
                Relay: de-fra-wg-001
                Visible location: Germany, Frankfurt.
                """,
                """
                Connected
                Relay: de-fra-wg-002
                Visible location: Germany, Frankfurt.
                """
            ],
            pingOutputs: [
                "round-trip min/avg/max/stddev = 10.0/23.4/50.0/3.2 ms",
                "round-trip min/avg/max/stddev = 20.0/45.6/70.0/3.2 ms"
            ]
        )
        let monitor = MullvadMonitor(
            processRunner: runner,
            statusPollInterval: 0,
            latencyProbeInterval: 30
        )

        let first = monitor.sample(downloadMbps: nil, approval: .approved)
        let second = monitor.sample(downloadMbps: nil, approval: .approved)
        let pingArguments = runner.recordedCalls()
            .filter { $0.executable == "/sbin/ping" }
            .map(\.arguments)

        XCTAssertEqual(first.latencyMs, 23.4)
        XCTAssertEqual(second.relayName, "de-fra-wg-002")
        XCTAssertEqual(second.latencyMs, 45.6)
        XCTAssertEqual(pingArguments, [
            ["-n", "-c", "3", "de-fra-wg-001.relays.mullvad.net"],
            ["-n", "-c", "3", "de-fra-wg-002.relays.mullvad.net"]
        ])
    }

    func testStatusReadFailureClearsCachedLatency() {
        let runner = SequenceProcessRunner(
            statusOutputs: [
                """
                Connected
                Relay: de-fra-wg-001
                Visible location: Germany, Frankfurt.
                """
            ],
            pingOutputs: [
                "round-trip min/avg/max/stddev = 10.0/23.4/50.0/3.2 ms"
            ]
        )
        let monitor = MullvadMonitor(
            processRunner: runner,
            statusPollInterval: 0,
            latencyProbeInterval: 30
        )

        let first = monitor.sample(downloadMbps: nil, approval: .approved)
        let second = monitor.sample(downloadMbps: nil, approval: .approved)
        let pingCalls = runner.recordedCalls().filter { $0.executable == "/sbin/ping" }

        XCTAssertEqual(first.latencyMs, 23.4)
        XCTAssertEqual(second.connection, .error)
        XCTAssertEqual(second.errorReason, .commandFailed)
        XCTAssertNil(second.latencyMs)
        XCTAssertEqual(pingCalls.count, 1)
    }

    func testParserExtractsConciseConnectedRelayAndLocation() {
        let status = MullvadStatusParser.parse(
            "Connected to se-mma-wg-001 in Malmo, Sweden via dk-cph-wg-001",
            cachedLatencyMs: 23.4,
            sampledAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(status.connection, .connected)
        XCTAssertEqual(status.countryCode, "SE")
        XCTAssertEqual(status.cityCode, "MMA")
        XCTAssertEqual(status.relayName, "se-mma-wg-001")
        XCTAssertEqual(status.visibleLocation, "Sweden, Malmo.")
        XCTAssertEqual(status.latencyMs, 23.4)
        XCTAssertEqual(status.stability, .connectedHealthy)
    }

    func testDiagnosticsRecordCommandsAndWarningCause() {
        let runner = RecordingProcessRunner { executable, _, _ in
            if executable == "/usr/bin/env" {
                return """
                Connected
                Relay: de-fra-wg-001
                Visible location: Germany, Frankfurt.
                """
            }

            if executable == "/sbin/ping" {
                return "round-trip min/avg/max/stddev = 460.0/520.0/620.0/3.2 ms"
            }

            return nil
        }
        let recorder = RecordingMullvadDiagnostics()
        let monitor = MullvadMonitor(
            processRunner: runner,
            diagnostics: MullvadDiagnostics(writeLine: recorder.record)
        )

        let status = monitor.sample(downloadMbps: nil, approval: .approved)
        let lines = recorder.recordedLines()

        XCTAssertEqual(status.stability, .connectedDegraded)
        XCTAssertTrue(lines.contains("veil_mullvad_command name=status timeout=2"))
        XCTAssertTrue(lines.contains("veil_mullvad_command name=ping target=relay_host timeout=4.2"))
        XCTAssertTrue(lines.contains("veil_mullvad_ping_result target=relay_host result=ok latency_ms=520"))
        XCTAssertTrue(lines.contains { line in
            line.contains("veil_mullvad_sample")
                && line.contains("stability=connectedDegraded")
                && line.contains("role=warning")
                && line.contains("warning=latencyHigh")
                && line.contains("latency_ms=520")
                && line.contains("location=FRA")
        })
        XCTAssertFalse(lines.contains { $0.contains("de-fra-wg-001") })
    }

    func testDiagnosticsExplainCliErrorWithoutStatusOutput() {
        let runner = RecordingProcessRunner()
        let recorder = RecordingMullvadDiagnostics()
        let monitor = MullvadMonitor(
            processRunner: runner,
            diagnostics: MullvadDiagnostics(writeLine: recorder.record)
        )

        let status = monitor.sample(downloadMbps: nil, approval: .approved)
        let lines = recorder.recordedLines()

        XCTAssertEqual(status.stability, .cliUnavailableOrError)
        XCTAssertTrue(lines.contains { line in
            line.contains("veil_mullvad_sample")
                && line.contains("role=warning")
                && line.contains("warning=cliUnavailableOrError")
                && line.contains("error=commandFailed")
        })
    }

    func testParserExtractsConnectedRelayAndLocation() {
        let status = MullvadStatusParser.parse(
            """
            Connected
            Relay: de-fra-wg-001
            Visible location: Germany, Frankfurt.
            """,
            cachedLatencyMs: 23.4,
            sampledAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(status.connection, .connected)
        XCTAssertEqual(status.countryCode, "DE")
        XCTAssertEqual(status.cityCode, "FRA")
        XCTAssertEqual(status.relayName, "de-fra-wg-001")
        XCTAssertEqual(status.visibleLocation, "Germany, Frankfurt.")
        XCTAssertEqual(status.latencyMs, 23.4)
        XCTAssertEqual(status.stability, .connectedHealthy)
        XCTAssertNil(status.errorReason)
    }

    func testParserExtractsConnectingAsTransientState() {
        let status = MullvadStatusParser.parse("Connecting")

        XCTAssertEqual(status.connection, .connecting)
        XCTAssertEqual(status.stability, .connectingTransient)
        XCTAssertNil(status.errorReason)
    }

    func testParserReturnsCliUnavailableForMissingMullvadOutput() {
        let status = MullvadStatusParser.parse("env: mullvad: No such file or directory")

        XCTAssertEqual(status.connection, .error)
        XCTAssertEqual(status.errorReason, .cliUnavailable)
        XCTAssertEqual(status.nodeHealth, .unknown)
        XCTAssertEqual(status.stability, .cliUnavailableOrError)
    }

    func testStabilityClassifierSupportsCoreStates() {
        XCTAssertEqual(Self.status(connection: .connected, nodeHealth: .normal).stability, .connectedHealthy)
        XCTAssertEqual(Self.status(connection: .connected, nodeHealth: .degraded).stability, .connectedDegraded)
        XCTAssertEqual(Self.status(connection: .connecting, nodeHealth: .unknown).stability, .connectingTransient)
        XCTAssertEqual(Self.status(connection: .disconnected, nodeHealth: .unknown).stability, .disconnected)
        XCTAssertEqual(Self.status(connection: .error, nodeHealth: .unknown, errorReason: .approvalRequired).stability, .approvalRequired)
        XCTAssertEqual(Self.status(connection: .error, nodeHealth: .unknown, errorReason: .approvalDenied).stability, .approvalDenied)
        XCTAssertEqual(Self.status(connection: .error, nodeHealth: .unknown, errorReason: .commandFailed).stability, .cliUnavailableOrError)
    }

    func testFlapTrackerEntersFlappingAfterThreeRollingTransitions() {
        let tracker = MullvadStabilityTracker(rollingWindow: 60, enterTransitionCount: 3, exitTransitionCount: 1)

        _ = tracker.update(Self.status(connection: .connected), at: Date(timeIntervalSince1970: 0))
        _ = tracker.update(Self.status(connection: .disconnected), at: Date(timeIntervalSince1970: 10))
        _ = tracker.update(Self.status(connection: .connected), at: Date(timeIntervalSince1970: 20))
        let status = tracker.update(Self.status(connection: .disconnected), at: Date(timeIntervalSince1970: 30))

        XCTAssertEqual(status.stability, .flapping)
        XCTAssertEqual(status.flapCount, 3)
    }

    func testFlapTrackerUsesExitHysteresisBeforeClearingFlapping() {
        let tracker = MullvadStabilityTracker(rollingWindow: 60, enterTransitionCount: 3, exitTransitionCount: 1)

        _ = tracker.update(Self.status(connection: .connected), at: Date(timeIntervalSince1970: 0))
        _ = tracker.update(Self.status(connection: .disconnected), at: Date(timeIntervalSince1970: 10))
        _ = tracker.update(Self.status(connection: .connected), at: Date(timeIntervalSince1970: 20))
        _ = tracker.update(Self.status(connection: .disconnected), at: Date(timeIntervalSince1970: 30))

        let held = tracker.update(Self.status(connection: .disconnected), at: Date(timeIntervalSince1970: 70))
        let cleared = tracker.update(Self.status(connection: .disconnected), at: Date(timeIntervalSince1970: 95))

        XCTAssertEqual(held.stability, .flapping)
        XCTAssertEqual(held.flapCount, 3)
        XCTAssertEqual(cleared.stability, .disconnected)
        XCTAssertNil(cleared.flapCount)
    }

    func testFlapTrackerDoesNotOverrideApprovalOrCliErrorStates() {
        let tracker = MullvadStabilityTracker(rollingWindow: 60, enterTransitionCount: 3, exitTransitionCount: 1)

        _ = tracker.update(Self.status(connection: .connected), at: Date(timeIntervalSince1970: 0))
        _ = tracker.update(Self.status(connection: .disconnected), at: Date(timeIntervalSince1970: 10))
        _ = tracker.update(Self.status(connection: .connected), at: Date(timeIntervalSince1970: 20))
        _ = tracker.update(Self.status(connection: .disconnected), at: Date(timeIntervalSince1970: 30))

        let approval = tracker.update(
            Self.status(connection: .error, errorReason: .approvalDenied),
            at: Date(timeIntervalSince1970: 40)
        )
        let cliError = tracker.update(
            Self.status(connection: .error, errorReason: .cliUnavailable),
            at: Date(timeIntervalSince1970: 50)
        )

        XCTAssertEqual(approval.stability, .approvalDenied)
        XCTAssertNil(approval.flapCount)
        XCTAssertEqual(cliError.stability, .cliUnavailableOrError)
        XCTAssertNil(cliError.flapCount)
    }

    private static func status(
        connection: VPNConnectionState,
        nodeHealth: VPNNodeHealth = .unknown,
        errorReason: VPNStatusErrorReason? = nil
    ) -> VPNStatus {
        VPNStatus(
            connection: connection,
            countryCode: connection == .connected ? "DE" : nil,
            cityCode: connection == .connected ? "FRA" : nil,
            relayName: connection == .connected ? "de-fra-wg-001" : nil,
            visibleLocation: connection == .connected ? "Germany, Frankfurt." : nil,
            latencyMs: connection == .connected ? 23.4 : nil,
            downloadMbps: nil,
            nodeHealth: nodeHealth,
            errorReason: errorReason,
            sampledAt: Date(timeIntervalSince1970: 0)
        )
    }
}

private final class RecordingProcessRunner: ProcessRunning, @unchecked Sendable {
    struct Call: Equatable {
        var executable: String
        var arguments: [String]
        var timeout: TimeInterval
    }

    private let lock = NSLock()
    private var calls: [Call] = []
    private let response: @Sendable (String, [String], TimeInterval) -> String?

    init(response: @escaping @Sendable (String, [String], TimeInterval) -> String? = { _, _, _ in nil }) {
        self.response = response
    }

    func run(_ executable: String, arguments: [String], timeout: TimeInterval) -> String? {
        lock.lock()
        calls.append(Call(executable: executable, arguments: arguments, timeout: timeout))
        lock.unlock()

        return response(executable, arguments, timeout)
    }

    func recordedCalls() -> [Call] {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
}

private final class RecordingMullvadDiagnostics: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []

    func record(_ line: String) {
        lock.lock()
        lines.append(line)
        lock.unlock()
    }

    func recordedLines() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }
}

private final class StaticVPNPathSpeedProbe: VPNPathSpeedProbing, @unchecked Sendable {
    struct Sample: Equatable {
        var passiveDownloadMbps: Double?
        var relayIdentifier: String?
        var at: Date
    }

    private let result: VPNPathSpeed
    private let lock = NSLock()
    private var samples: [Sample] = []
    private(set) var resetCount = 0

    init(result: VPNPathSpeed) {
        self.result = result
    }

    func sample(passiveDownloadMbps: Double?, relayIdentifier: String?, at now: Date) -> VPNPathSpeed {
        lock.lock()
        samples.append(
            Sample(
                passiveDownloadMbps: passiveDownloadMbps,
                relayIdentifier: relayIdentifier,
                at: now
            )
        )
        lock.unlock()
        return result
    }

    func reset() {
        lock.lock()
        resetCount += 1
        lock.unlock()
    }

    func recordedSamples() -> [Sample] {
        lock.lock()
        defer { lock.unlock() }
        return samples
    }
}

private final class TimedOutProcessRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [RecordingProcessRunner.Call] = []

    func run(_ executable: String, arguments: [String], timeout: TimeInterval) -> String? {
        nil
    }

    func runResult(_ executable: String, arguments: [String], timeout: TimeInterval) -> ProcessRunResult {
        lock.lock()
        calls.append(RecordingProcessRunner.Call(executable: executable, arguments: arguments, timeout: timeout))
        lock.unlock()

        return ProcessRunResult(
            standardOutput: "",
            standardError: "",
            termination: .timedOut
        )
    }

    func recordedCalls() -> [RecordingProcessRunner.Call] {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
}

private final class SequenceProcessRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [RecordingProcessRunner.Call] = []
    private var statusOutputs: [String]
    private var pingOutputs: [String]

    init(statusOutputs: [String], pingOutputs: [String]) {
        self.statusOutputs = statusOutputs
        self.pingOutputs = pingOutputs
    }

    func run(_ executable: String, arguments: [String], timeout: TimeInterval) -> String? {
        runResult(executable, arguments: arguments, timeout: timeout).legacyOutput
    }

    func runResult(_ executable: String, arguments: [String], timeout: TimeInterval) -> ProcessRunResult {
        lock.lock()
        calls.append(RecordingProcessRunner.Call(executable: executable, arguments: arguments, timeout: timeout))

        let output: String?
        if executable == "/usr/bin/env" {
            output = statusOutputs.isEmpty ? nil : statusOutputs.removeFirst()
        } else if executable == "/sbin/ping" {
            output = pingOutputs.isEmpty ? nil : pingOutputs.removeFirst()
        } else {
            output = nil
        }
        lock.unlock()

        guard let output else {
            return ProcessRunResult(
                standardOutput: "",
                standardError: "",
                termination: .failedToStart
            )
        }

        return ProcessRunResult(
            standardOutput: output,
            standardError: "",
            termination: .exited(0)
        )
    }

    func recordedCalls() -> [RecordingProcessRunner.Call] {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
}
