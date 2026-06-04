import XCTest
@testable import Veil

final class MemoryMonitorTests: XCTestCase {
    private let oneGiB: UInt64 = 1_073_741_824

    func testDisplayedUsedMatchesActivityMonitorLikeBuckets() {
        let used = MemoryMonitor.displayedUsedBytes(
            internalPages: 9 * oneGiB,
            purgeable: oneGiB,
            wired: 3 * oneGiB,
            compressed: 2 * oneGiB,
            total: 24 * oneGiB
        )
        let cached = MemoryMonitor.cachedFilesBytes(
            external: 7 * oneGiB,
            purgeable: oneGiB
        )

        XCTAssertEqual(used, 13 * oneGiB)
        XCTAssertEqual(cached, 8 * oneGiB)
    }

    func testDisplayedUsedCapsAtPhysicalMemory() {
        let used = MemoryMonitor.displayedUsedBytes(
            internalPages: 21 * oneGiB,
            purgeable: oneGiB,
            wired: 3 * oneGiB,
            compressed: 3 * oneGiB,
            total: 24 * oneGiB
        )

        XCTAssertEqual(used, 24 * oneGiB)
    }

    func testDisplayedUsedDoesNotUnderflowWhenPurgeableExceedsInternalPages() {
        let used = MemoryMonitor.displayedUsedBytes(
            internalPages: oneGiB,
            purgeable: 2 * oneGiB,
            wired: 3 * oneGiB,
            compressed: oneGiB,
            total: 24 * oneGiB
        )

        XCTAssertEqual(used, 4 * oneGiB)
    }

    func testPressureIsNormalWithHealthyAvailableMemoryAndSubTwoGiBSwap() {
        let pressure = MemoryMonitor.pressureLevel(
            total: 24 * oneGiB,
            available: 5 * oneGiB,
            compressed: 2 * oneGiB,
            swap: UInt64(Double(oneGiB) * 1.9)
        )

        XCTAssertEqual(pressure, .normal)
    }

    func testPressureBecomesElevatedAtTwoGiBSwap() {
        let pressure = MemoryMonitor.pressureLevel(
            total: 24 * oneGiB,
            available: 5 * oneGiB,
            compressed: 2 * oneGiB,
            swap: 2 * oneGiB
        )

        XCTAssertEqual(pressure, .elevated)
    }

    func testPressureStaysNormalWhenRetainedSwapHasHealthyAvailableMemory() {
        let pressure = MemoryMonitor.pressureLevel(
            total: 24 * oneGiB,
            available: 10 * oneGiB,
            compressed: 3 * oneGiB,
            swap: UInt64(Double(oneGiB) * 4.5)
        )

        XCTAssertEqual(pressure, .normal)
    }

    func testPressureBecomesElevatedBelowFifteenPercentAvailable() {
        let pressure = MemoryMonitor.pressureLevel(
            total: 24 * oneGiB,
            available: UInt64(Double(24 * oneGiB) * 0.149),
            compressed: 2 * oneGiB,
            swap: 0
        )

        XCTAssertEqual(pressure, .elevated)
    }

    func testPressureStaysNormalWhenOnlyCompressedMemoryIsElevated() {
        let total = 24 * oneGiB
        let pressure = MemoryMonitor.pressureLevel(
            total: total,
            available: UInt64(Double(total) * 0.26),
            compressed: UInt64(ceil(Double(total) * 0.25)),
            swap: 0
        )

        XCTAssertEqual(pressure, .normal)
    }

    func testPressureStaysNormalWhenCompressedMemoryIsHighButAvailableMemoryIsUsable() {
        let total = 24 * oneGiB
        let pressure = MemoryMonitor.pressureLevel(
            total: total,
            available: UInt64(Double(total) * 0.24),
            compressed: UInt64(ceil(Double(total) * 0.25)),
            swap: 0
        )

        XCTAssertEqual(pressure, .normal)
    }

    func testPressureBecomesHighAtFourGiBSwap() {
        let pressure = MemoryMonitor.pressureLevel(
            total: 24 * oneGiB,
            available: 3 * oneGiB,
            compressed: 2 * oneGiB,
            swap: 4 * oneGiB
        )

        XCTAssertEqual(pressure, .high)
    }

    func testPressureBecomesHighBelowEightPercentAvailable() {
        let pressure = MemoryMonitor.pressureLevel(
            total: 24 * oneGiB,
            available: UInt64(Double(24 * oneGiB) * 0.079),
            compressed: 2 * oneGiB,
            swap: 0
        )

        XCTAssertEqual(pressure, .high)
    }

    func testPressureBecomesHighWhenCompressedMemoryAndAvailableMemoryCorroborate() {
        let total = 24 * oneGiB
        let pressure = MemoryMonitor.pressureLevel(
            total: total,
            available: UInt64(Double(total) * 0.14),
            compressed: UInt64(ceil(Double(total) * 0.30)),
            swap: 0
        )

        XCTAssertEqual(pressure, .high)
    }

    func testPressureIsUnknownWithoutPhysicalMemoryTotal() {
        let pressure = MemoryMonitor.pressureLevel(
            total: nil,
            available: 5 * oneGiB,
            compressed: 2 * oneGiB,
            swap: 0
        )

        XCTAssertEqual(pressure, .unknown)
    }
}
