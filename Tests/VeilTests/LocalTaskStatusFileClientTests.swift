import Foundation
import XCTest
@testable import Veil

final class LocalTaskStatusFileClientTests: XCTestCase {
    func testMissingTaskStatusFileIsInactive() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("veil-missing-\(UUID().uuidString).json")

        let status = LocalTaskStatusFileClient.read(
            fileURL: url,
            staleAfterSeconds: 60,
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(status, .inactive)
    }

    func testDecodeRunningTaskStatusPayload() throws {
        let json = """
        {
          "state": "running",
          "tool": "codex",
          "message": "swift test",
          "updated_at": "2026-06-04T01:02:03Z"
        }
        """

        let status = LocalTaskStatusFileClient.decode(
            data: Data(json.utf8),
            staleAfterSeconds: 60,
            now: Date(timeIntervalSince1970: 1_780_000_000)
        )

        XCTAssertEqual(status.state, .running)
        XCTAssertEqual(status.label, "codex")
        XCTAssertEqual(status.detail, "swift test")
        XCTAssertEqual(status.updatedAt, ISO8601DateFormatter().date(from: "2026-06-04T01:02:03Z"))
    }

    func testDecodeSuccessAndFailureAliases() throws {
        let succeeded = LocalTaskStatusFileClient.decode(
            data: Data(#"{"status":"completed","label":"claude"}"#.utf8),
            staleAfterSeconds: 60,
            now: Date(timeIntervalSince1970: 0)
        )
        let failed = LocalTaskStatusFileClient.decode(
            data: Data(#"{"status":"error","label":"codex"}"#.utf8),
            staleAfterSeconds: 60,
            now: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(succeeded.state, .succeeded)
        XCTAssertEqual(succeeded.label, "claude")
        XCTAssertEqual(failed.state, .failed)
        XCTAssertEqual(failed.label, "codex")
    }

    func testDecodeOKBooleanAsTaskResultWhenStateIsMissing() throws {
        let status = LocalTaskStatusFileClient.decode(
            data: Data(#"{"ok":false,"tool":"runner"}"#.utf8),
            staleAfterSeconds: 60,
            now: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(status.state, .failed)
        XCTAssertEqual(status.label, "runner")
    }

    func testStaleStatusMarksNonInactivePayloadsStale() throws {
        let status = LocalTaskStatusFileClient.decode(
            data: Data(#"{"state":"running","updated_at":100}"#.utf8),
            staleAfterSeconds: 60,
            now: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(status.state, .stale)
        XCTAssertEqual(status.updatedAt, Date(timeIntervalSince1970: 100))
    }

    func testInvalidJSONReturnsUnknownTaskStatus() throws {
        let status = LocalTaskStatusFileClient.decode(
            data: Data("not-json".utf8),
            staleAfterSeconds: 60,
            now: Date(timeIntervalSince1970: 10)
        )

        XCTAssertEqual(status.state, .unknown)
        XCTAssertEqual(status.label, "task")
        XCTAssertEqual(status.detail, "json_invalid")
        XCTAssertEqual(status.updatedAt, Date(timeIntervalSince1970: 10))
    }
}
