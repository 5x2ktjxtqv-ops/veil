import XCTest
@testable import Veil

final class ProcessRunnerTests: XCTestCase {
    func testRunResultCapturesStdout() {
        let result = ProcessRunner.runResult(
            "/bin/echo",
            arguments: ["hello"],
            timeout: 1
        )

        XCTAssertEqual(result.termination, .exited(0))
        XCTAssertEqual(result.output, "hello")
        XCTAssertEqual(result.legacyOutput, "hello")
    }

    func testRunResultCapturesStderrForNonZeroExit() {
        let result = ProcessRunner.runResult(
            "/bin/ls",
            arguments: ["/definitely/missing/veil/path"],
            timeout: 1
        )

        XCTAssertEqual(result.termination, .exited(1))
        XCTAssertTrue(result.output.contains("No such file"))
        XCTAssertNotNil(result.legacyOutput)
    }

    func testRunResultOutputCombinesStdoutAndStderr() {
        let result = ProcessRunResult(
            standardOutput: "ready\n",
            standardError: "warning\n",
            termination: .exited(0)
        )

        XCTAssertEqual(result.output, "ready\nwarning")
        XCTAssertEqual(result.legacyOutput, "ready\nwarning")
    }

    func testRunResultReportsTimeoutWithoutLegacyOutput() {
        let result = ProcessRunner.runResult(
            "/bin/sleep",
            arguments: ["1"],
            timeout: 0.01
        )

        XCTAssertEqual(result.termination, .timedOut)
        XCTAssertNil(result.legacyOutput)
    }
}
