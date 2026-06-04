import AppKit
import XCTest
@testable import Veil

final class StatusHUDConfigurationTests: XCTestCase {
    func testProductionCompactUsesFrozenNotchCapsuleBaseline() {
        XCTAssertEqual(StatusHUDConfiguration.productionCompact, .notchCapsule)
        XCTAssertEqual(StatusHUDConfiguration.productionCompact.mode, .notchCapsule)
        XCTAssertEqual(StatusHUDConfiguration.productionCompact.width, 320)
        XCTAssertEqual(StatusHUDConfiguration.productionCompact.height, 32)
        XCTAssertEqual(StatusHUDConfiguration.productionCompact.notchStyle.screenInsetWidth, 30)
        XCTAssertEqual(StatusHUDConfiguration.productionCompact.notchStyle.screenCornerWidth, 4.5)
        XCTAssertEqual(StatusHUDConfiguration.productionCompact.notchStyle.screenCornerHeight, 5.5)
        XCTAssertEqual(StatusHUDConfiguration.productionCompact.notchStyle.screenCornerControl, 0.50)
        XCTAssertEqual(StatusHUDConfiguration.productionCompact.notchStyle.bottomCornerWidth, 14)
        XCTAssertEqual(StatusHUDConfiguration.productionCompact.notchStyle.bottomCornerHeight, 9)
        XCTAssertEqual(StatusHUDConfiguration.productionCompact.notchStyle.bottomCornerControl, 0.78)
        XCTAssertTrue(StatusHUDConfiguration.productionCompact.showsSignals)
    }

    func testNotchCapsuleLayoutUsesFrozenWingWidthWithinMinimumMargins() {
        let totalWidth = NotchCapsuleLayout.defaultWidth
        let wingWidth = NotchCapsuleLayout.wingWidth(for: totalWidth)
        let notchVoidWidth = NotchCapsuleLayout.notchVoidWidth(for: totalWidth)
        let occupiedWidth = NotchCapsuleLayout.minimumVisualMargin * 2
            + wingWidth * 2
            + notchVoidWidth

        XCTAssertEqual(NotchCapsuleLayout.minimumVisualMargin, 34)
        XCTAssertEqual(NotchCapsuleLayout.referenceNotchVoidWidth, 180)
        XCTAssertEqual(NotchCapsuleLayout.referenceWingSafetyPadding, 2)
        XCTAssertEqual(NotchCapsuleLayout.referenceWingWidth, 36)
        XCTAssertEqual(NotchCapsuleLayout.defaultWidth, 320)
        XCTAssertEqual(NotchCapsuleLayout.defaultSideOverhang, 70)
        XCTAssertGreaterThanOrEqual(wingWidth, NotchCapsuleLayout.referenceWingWidth)
        XCTAssertGreaterThanOrEqual(notchVoidWidth, NotchCapsuleLayout.referenceNotchVoidWidth)
        XCTAssertEqual(occupiedWidth, totalWidth, accuracy: 0.5)
    }

    func testResolvedSizeKeepsModeAndNotchStyle() {
        let resolved = StatusHUDConfiguration.notchCapsule.withSize(
            CGSize(width: 372, height: 36)
        )

        XCTAssertEqual(resolved.mode, .notchCapsule)
        XCTAssertEqual(resolved.width, 372)
        XCTAssertEqual(resolved.height, 36)
        XCTAssertEqual(resolved.notchStyle, StatusHUDConfiguration.notchCapsule.notchStyle)
        XCTAssertEqual(resolved.showsSignals, StatusHUDConfiguration.notchCapsule.showsSignals)
    }

    func testSignalVisibilityCanBeDisabledWithoutChangingGeometry() {
        let resolved = StatusHUDConfiguration.notchCapsule.withSignals(false)

        XCTAssertEqual(resolved.mode, .notchCapsule)
        XCTAssertEqual(resolved.width, StatusHUDConfiguration.notchCapsule.width)
        XCTAssertEqual(resolved.height, StatusHUDConfiguration.notchCapsule.height)
        XCTAssertEqual(resolved.notchStyle, StatusHUDConfiguration.notchCapsule.notchStyle)
        XCTAssertFalse(resolved.showsSignals)
    }

    func testHardwareBlackUsesOfficialImageMedianBlack() {
        XCTAssertEqual(VeilHardwareBlack.red, 0)
        XCTAssertEqual(VeilHardwareBlack.green, 0)
        XCTAssertEqual(VeilHardwareBlack.blue, 0)
        XCTAssertEqual(VeilHardwareBlack.notchEdgeCoverageOpacity, 0.18)
    }

    func testNotchCapsuleCoverageUsesVisibleTopInsetWhenItExceedsSafeArea() {
        let height = NotchCapsuleScreenGeometry.coverageHeight(
            frame: NSRect(x: 0, y: 0, width: 1470, height: 956),
            visibleFrame: NSRect(x: 0, y: 90, width: 1470, height: 833),
            safeAreaInsets: NSEdgeInsets(top: 32, left: 0, bottom: 0, right: 0),
            minimumHeight: 32
        )

        XCTAssertEqual(height, 33)
    }

    func testNotchCapsuleCoverageFallsBackToSafeAreaWhenVisibleTopInsetIsAbsent() {
        let height = NotchCapsuleScreenGeometry.coverageHeight(
            frame: NSRect(x: 0, y: 0, width: 1470, height: 956),
            visibleFrame: NSRect(x: 0, y: 0, width: 1470, height: 956),
            safeAreaInsets: NSEdgeInsets(top: 32, left: 0, bottom: 0, right: 0),
            minimumHeight: 32
        )

        XCTAssertEqual(height, 32)
    }
}
