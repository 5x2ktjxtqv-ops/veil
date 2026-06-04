import XCTest
@testable import Veil

final class PrivilegedRelauncherTests: XCTestCase {
    func testNonSystemPowerModeDoesNotRelaunch() {
        let runner = PrivilegedRelaunchRecordingRunner()
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["/Applications/Veil.app/Contents/MacOS/Veil"]
        )

        let relauncher = PrivilegedRelauncher(
            processRunner: runner,
            rootPrivilegeChecker: PrivilegedRelaunchRootChecker(isRunningAsRoot: false),
            environment: [:],
            arguments: ["/Applications/Veil.app/Contents/MacOS/Veil"]
        )

        XCTAssertEqual(relauncher.relaunchIfNeeded(for: configuration), .notNeeded)
        XCTAssertTrue(runner.invocations.isEmpty)
    }

    func testRootSystemPowerModeDoesNotRelaunch() {
        let runner = PrivilegedRelaunchRecordingRunner()
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["/Applications/Veil.app/Contents/MacOS/Veil", "--system-power-keepalive"]
        )

        let relauncher = PrivilegedRelauncher(
            processRunner: runner,
            rootPrivilegeChecker: PrivilegedRelaunchRootChecker(isRunningAsRoot: true),
            environment: [:],
            arguments: ["/Applications/Veil.app/Contents/MacOS/Veil", "--system-power-keepalive"]
        )

        XCTAssertEqual(relauncher.relaunchIfNeeded(for: configuration), .notNeeded)
        XCTAssertTrue(runner.invocations.isEmpty)
    }

    func testAlreadyAttemptedSystemPowerModeDoesNotRelaunchAgain() {
        let runner = PrivilegedRelaunchRecordingRunner()
        let configuration = RuntimeConfiguration.load(
            environment: [:],
            arguments: ["/Applications/Veil.app/Contents/MacOS/Veil", "--system-power-keepalive"]
        )

        let relauncher = PrivilegedRelauncher(
            processRunner: runner,
            rootPrivilegeChecker: PrivilegedRelaunchRootChecker(isRunningAsRoot: false),
            environment: [PrivilegedRelauncher.elevationAttemptedEnvironmentKey: "1"],
            arguments: ["/Applications/Veil.app/Contents/MacOS/Veil", "--system-power-keepalive"]
        )

        XCTAssertEqual(relauncher.relaunchIfNeeded(for: configuration), .notNeeded)
        XCTAssertTrue(runner.invocations.isEmpty)
    }

    func testSystemPowerModeRelaunchesThroughAdministratorPrompt() throws {
        let runner = PrivilegedRelaunchRecordingRunner()
        let arguments = [
            "/Applications/Veil.app/Contents/MacOS/Veil",
            "--approve-mullvad-readonly",
            "--no-mullvad-approval-prompt",
            "--system-power-keepalive"
        ]
        let configuration = RuntimeConfiguration.load(environment: [:], arguments: arguments)

        let relauncher = PrivilegedRelauncher(
            processRunner: runner,
            rootPrivilegeChecker: PrivilegedRelaunchRootChecker(isRunningAsRoot: false),
            environment: [:],
            arguments: arguments
        )

        XCTAssertEqual(relauncher.relaunchIfNeeded(for: configuration), .launched)

        let invocation = try XCTUnwrap(runner.invocations.first)
        XCTAssertEqual(invocation.executable, "/usr/bin/osascript")
        XCTAssertEqual(invocation.timeout, 120)

        let script = try XCTUnwrap(invocation.arguments.last)
        XCTAssertTrue(script.contains("with administrator privileges"))
        XCTAssertTrue(script.contains("trap '' HUP"))
        XCTAssertFalse(script.contains("nohup"))
        XCTAssertFalse(script.contains("/tmp/veil-system-power-keepalive.log"))
        XCTAssertTrue(script.contains(">/dev/null 2>&1 < /dev/null &"))
        XCTAssertTrue(script.contains("VEIL_ELEVATION_ATTEMPTED=1"))
        XCTAssertTrue(script.contains("VEIL_SYSTEM_POWER_KEEPALIVE=1"))
        XCTAssertTrue(script.contains("--approve-mullvad-readonly"))
        XCTAssertTrue(script.contains("--no-mullvad-approval-prompt"))
        XCTAssertEqual(script.components(separatedBy: "--system-power-keepalive").count - 1, 1)
    }

    func testShellAndAppleScriptQuotingEscapesUnsafeCharacters() {
        XCTAssertEqual(
            PrivilegedRelauncher.shellQuoted("/tmp/Veil John's.app/Veil"),
            "'/tmp/Veil John'\\''s.app/Veil'"
        )
        XCTAssertEqual(
            PrivilegedRelauncher.appleScriptStringLiteral("say \"hi\" \\ done"),
            "\"say \\\"hi\\\" \\\\ done\""
        )
    }
}

private struct PrivilegedRelaunchRootChecker: RootPrivilegeChecking {
    var isRunningAsRoot: Bool
}

private final class PrivilegedRelaunchRecordingRunner: ProcessRunning, @unchecked Sendable {
    struct Invocation {
        var executable: String
        var arguments: [String]
        var timeout: TimeInterval
    }

    private(set) var invocations: [Invocation] = []
    var result = ProcessRunResult(
        standardOutput: "",
        standardError: "",
        termination: .exited(0)
    )

    func runResult(_ executable: String, arguments: [String], timeout: TimeInterval) -> ProcessRunResult {
        invocations.append(Invocation(executable: executable, arguments: arguments, timeout: timeout))
        return result
    }
}
