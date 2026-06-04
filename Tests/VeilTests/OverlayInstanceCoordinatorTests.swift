import Foundation
import XCTest
@testable import Veil

final class OverlayInstanceCoordinatorTests: XCTestCase {
    func testAcquireCreatesOverlayLease() throws {
        let lockURL = try temporaryLockURL()

        let lease = try XCTUnwrap(acquireLease(lockURL: lockURL, processIdentifier: 101))
        defer { lease.invalidate() }

        XCTAssertEqual(
            try String(contentsOf: lockURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
            "101"
        )
    }

    func testSecondAcquireFailsWhileLeaseIsActive() throws {
        let lockURL = try temporaryLockURL()
        let firstLease = try XCTUnwrap(acquireLease(lockURL: lockURL, processIdentifier: 101))
        defer { firstLease.invalidate() }

        switch OverlayInstanceCoordinator.acquire(lockURL: lockURL, processIdentifier: 202) {
        case .success(let secondLease):
            secondLease.invalidate()
            XCTFail("Expected active overlay ownership to reject a second lease.")
        case .failure(.alreadyRunning(let ownerProcessIdentifier)):
            XCTAssertEqual(ownerProcessIdentifier, 101)
        case .failure(let error):
            XCTFail("Expected alreadyRunning, got \(error).")
        }
    }

    func testAcquireSucceedsAfterLeaseIsReleased() throws {
        let lockURL = try temporaryLockURL()
        let firstLease = try XCTUnwrap(acquireLease(lockURL: lockURL, processIdentifier: 101))
        firstLease.invalidate()

        let secondLease = try XCTUnwrap(acquireLease(lockURL: lockURL, processIdentifier: 202))
        defer { secondLease.invalidate() }

        XCTAssertEqual(
            try String(contentsOf: lockURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
            "202"
        )
    }

    private func acquireLease(lockURL: URL, processIdentifier: pid_t) -> OverlayInstanceLease? {
        switch OverlayInstanceCoordinator.acquire(lockURL: lockURL, processIdentifier: processIdentifier) {
        case .success(let lease):
            return lease
        case .failure(let error):
            XCTFail("Expected overlay ownership lease, got \(error).")
            return nil
        }
    }

    private func temporaryLockURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("veil-overlay.lock")
    }
}
