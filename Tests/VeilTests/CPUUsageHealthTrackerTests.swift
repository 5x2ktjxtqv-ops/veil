import XCTest
@testable import Veil

final class CPUUsageHealthTrackerTests: XCTestCase {
    func testWarningRequiresSustainedHighUsageAndHysteresisToRecover() {
        var tracker = CPUUsageHealthTracker(sustainedDuration: 15)
        let start = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(tracker.update(usagePercent: 82, at: start), HealthLevel.normal)
        XCTAssertEqual(tracker.update(usagePercent: 82, at: start.addingTimeInterval(10)), HealthLevel.normal)
        XCTAssertEqual(tracker.update(usagePercent: 82, at: start.addingTimeInterval(15)), HealthLevel.elevated)
        XCTAssertEqual(tracker.update(usagePercent: 70, at: start.addingTimeInterval(20)), HealthLevel.elevated)
        XCTAssertEqual(tracker.update(usagePercent: 64, at: start.addingTimeInterval(25)), HealthLevel.normal)
    }

    func testCriticalRequiresSustainedCriticalUsageAndStepsDownWithHysteresis() {
        var tracker = CPUUsageHealthTracker(sustainedDuration: 15)
        let start = Date(timeIntervalSince1970: 200)

        XCTAssertEqual(tracker.update(usagePercent: 96, at: start), HealthLevel.normal)
        XCTAssertEqual(tracker.update(usagePercent: 96, at: start.addingTimeInterval(15)), HealthLevel.high)
        XCTAssertEqual(tracker.update(usagePercent: 90, at: start.addingTimeInterval(20)), HealthLevel.high)
        XCTAssertEqual(tracker.update(usagePercent: 84, at: start.addingTimeInterval(25)), HealthLevel.elevated)
        XCTAssertEqual(tracker.update(usagePercent: 64, at: start.addingTimeInterval(30)), HealthLevel.normal)
    }

    func testUnavailableUsageIsUnknownAndNextValidSampleStartsNormal() {
        var tracker = CPUUsageHealthTracker(sustainedDuration: 15)
        let start = Date(timeIntervalSince1970: 300)

        XCTAssertEqual(tracker.update(usagePercent: nil as Double?, at: start), HealthLevel.unknown)
        XCTAssertEqual(tracker.update(usagePercent: 18, at: start.addingTimeInterval(5)), HealthLevel.normal)
    }
}
