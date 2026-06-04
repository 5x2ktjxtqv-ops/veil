import CoreGraphics
import XCTest
@testable import Veil

final class BottomCornerFullscreenDetectorTests: XCTestCase {
    func testWindowCoveringDisplayCountsAsFullscreen() {
        XCTAssertTrue(
            BottomCornerFullscreenDetector.windowCoversDisplay(
                windowBounds: CGRect(x: 0, y: 0, width: 1470, height: 956),
                displayBounds: CGRect(x: 0, y: 0, width: 1470, height: 956)
            )
        )
    }

    func testNearlyCoveringDisplayUsesSmallTolerance() {
        XCTAssertTrue(
            BottomCornerFullscreenDetector.windowCoversDisplay(
                windowBounds: CGRect(x: 1, y: 1, width: 1468, height: 954),
                displayBounds: CGRect(x: 0, y: 0, width: 1470, height: 956)
            )
        )
    }

    func testMaximizedWindowLeavingMenuBarVisibleDoesNotCountAsFullscreen() {
        XCTAssertFalse(
            BottomCornerFullscreenDetector.windowCoversDisplay(
                windowBounds: CGRect(x: 0, y: 38, width: 1470, height: 918),
                displayBounds: CGRect(x: 0, y: 0, width: 1470, height: 956)
            )
        )
    }
}
