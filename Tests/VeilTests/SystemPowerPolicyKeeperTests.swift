import XCTest
@testable import Veil

final class SystemPowerPolicyKeeperTests: XCTestCase {
    func testParseCustomSettingsCapturesOnlyManagedSettingsByPowerSource() {
        let output = """
        Battery Power:
         Sleep On Power Button 1
         lowpowermode         1
         standby              1
         hibernatemode        3
         displaysleep         5
         sleep                1
         tcpkeepalive         1
         disksleep            10
        AC Power:
         lowpowermode         0
         standby              1
         displaysleep         5
         sleep                0 (sleep prevented by powerd)
         tcpkeepalive         1
         disksleep            10
        """

        let snapshot = PMSetSystemPowerPolicyManager.parseCustomSettings(output)

        XCTAssertEqual(snapshot.values[.battery]?[.sleep], "1")
        XCTAssertEqual(snapshot.values[.battery]?[.disksleep], "10")
        XCTAssertEqual(snapshot.values[.battery]?[.lowpowermode], "1")
        XCTAssertEqual(snapshot.values[.charger]?[.sleep], "0")
    }

    func testActivateRequiresRootAndDoesNotRunPmsetMutations() {
        let runner = RecordingSystemPolicyProcessRunner()
        let manager = PMSetSystemPowerPolicyManager(
            processRunner: runner,
            rootPrivilegeChecker: StubRootPrivilegeChecker(isRunningAsRoot: false)
        )

        let status = manager.activate()

        XCTAssertFalse(status.isActive)
        XCTAssertEqual(status.failures.map(\.reason), [.requiresRoot])
        XCTAssertTrue(runner.calls().isEmpty)
    }

    func testActivateSnapshotsAndAppliesSupportedSystemPolicyWithoutDisplaySleep() {
        let runner = RecordingSystemPolicyProcessRunner(outputs: [
            ["-g", "custom"]: .success(Self.customSettings),
            ["-g", "cap"]: .success("""
            Capabilities for AC Power:
             displaysleep
             disksleep
             sleep
             womp
             standby
             powernap
             ttyskeepawake
             tcpkeepalive
             lowpowermode
            """),
            ["-a", "sleep", "0", "disksleep", "0", "standby", "0", "lowpowermode", "0", "tcpkeepalive", "1", "ttyskeepawake", "1", "powernap", "1", "womp", "1"]: .success(""),
            ["-a", "disablesleep", "1"]: .success("")
        ])
        let manager = PMSetSystemPowerPolicyManager(
            processRunner: runner,
            rootPrivilegeChecker: StubRootPrivilegeChecker(isRunningAsRoot: true)
        )

        let status = manager.activate()

        XCTAssertTrue(status.isActive)
        XCTAssertEqual(status.appliedSettings, [
            .sleep,
            .disksleep,
            .standby,
            .lowpowermode,
            .tcpkeepalive,
            .ttyskeepawake,
            .powernap,
            .womp
        ])
        XCTAssertTrue(status.appliedDisableSleep)
        XCTAssertFalse(runner.calls().contains { $0.arguments.contains("displaysleep") })
    }

    func testRestoreUsesOriginalPerPowerSourceSnapshotAndDisablesDisableSleep() {
        let runner = RecordingSystemPolicyProcessRunner(outputs: [
            ["-g", "custom"]: .success(Self.customSettings),
            ["-g", "cap"]: .success("""
            Capabilities for AC Power:
             disksleep
             sleep
             standby
             tcpkeepalive
             lowpowermode
            """),
            ["-a", "sleep", "0", "disksleep", "0", "standby", "0", "lowpowermode", "0", "tcpkeepalive", "1"]: .success(""),
            ["-a", "disablesleep", "1"]: .success(""),
            ["-b", "sleep", "1", "disksleep", "10", "standby", "1", "lowpowermode", "1", "tcpkeepalive", "1"]: .success(""),
            ["-c", "sleep", "0", "disksleep", "10", "standby", "1", "lowpowermode", "0", "tcpkeepalive", "1"]: .success(""),
            ["-a", "disablesleep", "0"]: .success("")
        ])
        let manager = PMSetSystemPowerPolicyManager(
            processRunner: runner,
            rootPrivilegeChecker: StubRootPrivilegeChecker(isRunningAsRoot: true)
        )

        _ = manager.activate()
        let restoreStatus = manager.restore()

        XCTAssertTrue(restoreStatus.failures.isEmpty)
        XCTAssertTrue(runner.calls().contains { $0.arguments == ["-b", "sleep", "1", "disksleep", "10", "standby", "1", "lowpowermode", "1", "tcpkeepalive", "1"] })
        XCTAssertTrue(runner.calls().contains { $0.arguments == ["-c", "sleep", "0", "disksleep", "10", "standby", "1", "lowpowermode", "0", "tcpkeepalive", "1"] })
        XCTAssertTrue(runner.calls().contains { $0.arguments == ["-a", "disablesleep", "0"] })
    }

    func testVerifyReportsDriftFromTargetPowerPolicy() {
        let runner = RecordingSystemPolicyProcessRunner(outputs: [
            ["-g", "custom"]: .success(Self.customSettings),
            ["-g", "cap"]: .success("""
            Capabilities for AC Power:
             disksleep
             sleep
             standby
             tcpkeepalive
             lowpowermode
            """),
            ["-a", "sleep", "0", "disksleep", "0", "standby", "0", "lowpowermode", "0", "tcpkeepalive", "1"]: .success(""),
            ["-a", "disablesleep", "1"]: .success("")
        ])
        let manager = PMSetSystemPowerPolicyManager(
            processRunner: runner,
            rootPrivilegeChecker: StubRootPrivilegeChecker(isRunningAsRoot: true)
        )

        _ = manager.activate()
        let status = manager.verify()

        XCTAssertFalse(status.isActive)
        XCTAssertTrue(status.failures.contains {
            $0.reason == .verificationFailed
                && $0.arguments == ["-b", "sleep", "0"]
                && $0.output == "observed sleep=1"
        })
        XCTAssertTrue(status.failures.contains {
            $0.reason == .verificationFailed
                && $0.arguments == ["-b", "standby", "0"]
                && $0.output == "observed standby=1"
        })
    }

    private static let customSettings = """
    Battery Power:
     lowpowermode         1
     standby              1
     displaysleep         5
     sleep                1
     tcpkeepalive         1
     disksleep            10
    AC Power:
     lowpowermode         0
     standby              1
     displaysleep         5
     sleep                0
     tcpkeepalive         1
     disksleep            10
    """
}

private struct StubRootPrivilegeChecker: RootPrivilegeChecking {
    var isRunningAsRoot: Bool
}

private final class RecordingSystemPolicyProcessRunner: ProcessRunning, @unchecked Sendable {
    struct Call: Equatable {
        var executable: String
        var arguments: [String]
        var timeout: TimeInterval
    }

    enum Output {
        case success(String)
        case failure(String)
    }

    private let lock = NSLock()
    private let outputs: [[String]: Output]
    private var recordedCalls: [Call] = []

    init(outputs: [[String]: Output] = [:]) {
        self.outputs = outputs
    }

    func runResult(_ executable: String, arguments: [String], timeout: TimeInterval) -> ProcessRunResult {
        lock.lock()
        recordedCalls.append(Call(executable: executable, arguments: arguments, timeout: timeout))
        lock.unlock()

        switch outputs[arguments] ?? .success("") {
        case .success(let output):
            return ProcessRunResult(standardOutput: output, standardError: "", termination: .exited(0))
        case .failure(let output):
            return ProcessRunResult(standardOutput: "", standardError: output, termination: .exited(1))
        }
    }

    func calls() -> [Call] {
        lock.lock()
        defer { lock.unlock() }
        return recordedCalls
    }
}
