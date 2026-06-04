import AppKit
import XCTest
@testable import Veil

final class BottomCornerMaskRendererTests: XCTestCase {
    func testRendererUsesExactRetinaPixelDimensions() throws {
        let image = BottomCornerMaskRenderer.renderMaskImage(
            corner: .bottomLeft,
            size: NSSize(width: 24, height: 24),
            backingScale: 2
        )

        let representation = try XCTUnwrap(image.representations.first as? NSBitmapImageRep)

        XCTAssertEqual(representation.pixelsWide, 48)
        XCTAssertEqual(representation.pixelsHigh, 48)
        XCTAssertEqual(representation.size, NSSize(width: 24, height: 24))
    }

    func testRendererProducesSmoothAntialiasedBoundary() throws {
        let image = try XCTUnwrap(
            BottomCornerMaskRenderer.renderMaskCGImage(
                corner: .bottomLeft,
                size: NSSize(width: 24, height: 24),
                backingScale: 2
            )
        )
        let alphaValues = try alphaValues(in: image)
        let antialiasSamples = alphaValues.filter { $0 > 0 && $0 < 255 }

        XCTAssertTrue(alphaValues.contains(0))
        XCTAssertTrue(alphaValues.contains(255))
        XCTAssertGreaterThan(antialiasSamples.count, 20)
        XCTAssertLessThan(antialiasSamples.count, 180)
    }

    func testRendererCoverageMatchesQuarterCircleCutout() throws {
        let image = try XCTUnwrap(
            BottomCornerMaskRenderer.renderMaskCGImage(
                corner: .bottomLeft,
                size: NSSize(width: 24, height: 24),
                backingScale: 2
            )
        )
        let alphaCoverage = try alphaValues(in: image)
            .reduce(0.0) { $0 + Double($1) / 255.0 }

        let radius = 48.0
        let expectedCoverage = radius * radius - Double.pi * radius * radius / 4.0
        XCTAssertEqual(alphaCoverage, expectedCoverage, accuracy: 35.0)
    }

    func testRightMaskMirrorsLeftMask() throws {
        let left = try XCTUnwrap(
            BottomCornerMaskRenderer.renderMaskCGImage(
                corner: .bottomLeft,
                size: NSSize(width: 24, height: 24),
                backingScale: 2
            )
        )
        let right = try XCTUnwrap(
            BottomCornerMaskRenderer.renderMaskCGImage(
                corner: .bottomRight,
                size: NSSize(width: 24, height: 24),
                backingScale: 2
            )
        )
        let leftAlphaValues = try alphaValues(in: left)
        let rightAlphaValues = try alphaValues(in: right)
        let width = left.width
        let height = left.height

        for y in 0..<height {
            for x in 0..<width {
                XCTAssertEqual(
                    leftAlphaValues[y * width + x],
                    rightAlphaValues[y * width + (width - x - 1)]
                )
            }
        }
    }

    func testRendererSupportsPixelBleedAroundFittedRadius() throws {
        let size = NSSize(width: 22, height: 22)
        let radius = 21.2
        let left = try XCTUnwrap(
            BottomCornerMaskRenderer.renderMaskCGImage(
                corner: .bottomLeft,
                size: size,
                cornerRadius: radius,
                backingScale: 2
            )
        )
        let right = try XCTUnwrap(
            BottomCornerMaskRenderer.renderMaskCGImage(
                corner: .bottomRight,
                size: size,
                cornerRadius: radius,
                backingScale: 2
            )
        )
        let leftAlphaValues = try alphaValues(in: left)
        let rightAlphaValues = try alphaValues(in: right)
        let width = left.width
        let height = left.height

        XCTAssertEqual(width, 44)
        XCTAssertEqual(height, 44)

        for y in 0..<height {
            for x in 0..<width {
                let leftAlpha = Int(leftAlphaValues[y * width + x])
                let rightAlpha = Int(rightAlphaValues[y * width + (width - x - 1)])
                XCTAssertLessThanOrEqual(abs(leftAlpha - rightAlpha), 2)
            }
        }

        XCTAssertGreaterThan(leftAlphaValues[0], 0)
        XCTAssertGreaterThan(rightAlphaValues[width - 1], 0)
    }

    func testRendererUsesSharedHardwareBlackFill() throws {
        let image = try XCTUnwrap(
            BottomCornerMaskRenderer.renderMaskCGImage(
                corner: .bottomLeft,
                size: NSSize(width: 24, height: 24),
                backingScale: 2
            )
        )
        let pixels = try rgbaValues(in: image)
        let filledPixel = try XCTUnwrap(pixels.first { $0.alpha == 255 })

        XCTAssertEqual(filledPixel.red, UInt8(VeilHardwareBlack.red * 255))
        XCTAssertEqual(filledPixel.green, UInt8(VeilHardwareBlack.green * 255))
        XCTAssertEqual(filledPixel.blue, UInt8(VeilHardwareBlack.blue * 255))
    }

    private func alphaValues(in image: CGImage) throws -> [UInt8] {
        XCTAssertEqual(image.bitsPerPixel, 32)
        XCTAssertEqual(image.bitsPerComponent, 8)

        let data = try XCTUnwrap(image.dataProvider?.data)
        let pointer = try XCTUnwrap(CFDataGetBytePtr(data))
        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow

        return (0..<image.height).flatMap { y in
            (0..<image.width).map { x in
                pointer[y * bytesPerRow + x * bytesPerPixel + 3]
            }
        }
    }

    private func rgbaValues(in image: CGImage) throws -> [(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)] {
        XCTAssertEqual(image.bitsPerPixel, 32)
        XCTAssertEqual(image.bitsPerComponent, 8)

        let data = try XCTUnwrap(image.dataProvider?.data)
        let pointer = try XCTUnwrap(CFDataGetBytePtr(data))
        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow

        return (0..<image.height).flatMap { y in
            (0..<image.width).map { x in
                let offset = y * bytesPerRow + x * bytesPerPixel
                return (
                    red: pointer[offset],
                    green: pointer[offset + 1],
                    blue: pointer[offset + 2],
                    alpha: pointer[offset + 3]
                )
            }
        }
    }
}
