#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let assetDirectory = root.appendingPathComponent("Assets/VeilIcon", isDirectory: true)
private let iconsetDirectory = assetDirectory.appendingPathComponent("VeilIcon.iconset", isDirectory: true)
private let previewURL = assetDirectory.appendingPathComponent("VeilIcon-1024.png")
private let lightPreviewURL = assetDirectory.appendingPathComponent("VeilIcon-preview-light.png")
private let icnsURL = assetDirectory.appendingPathComponent("VeilIcon.icns")
private let colorSpace = CGColorSpaceCreateDeviceRGB()

private struct IconSize {
    var filename: String
    var pixels: Int
}

private let iconSizes = [
    IconSize(filename: "icon_16x16.png", pixels: 16),
    IconSize(filename: "icon_16x16@2x.png", pixels: 32),
    IconSize(filename: "icon_32x32.png", pixels: 32),
    IconSize(filename: "icon_32x32@2x.png", pixels: 64),
    IconSize(filename: "icon_128x128.png", pixels: 128),
    IconSize(filename: "icon_128x128@2x.png", pixels: 256),
    IconSize(filename: "icon_256x256.png", pixels: 256),
    IconSize(filename: "icon_256x256@2x.png", pixels: 512),
    IconSize(filename: "icon_512x512.png", pixels: 512),
    IconSize(filename: "icon_512x512@2x.png", pixels: 1024)
]

try FileManager.default.createDirectory(at: assetDirectory, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconsetDirectory)
try FileManager.default.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

try writePNG(size: 1024, to: previewURL)
try writePNG(size: 1024, to: lightPreviewURL, background: color(0xF5F5F7))

for iconSize in iconSizes {
    try writePNG(size: iconSize.pixels, to: iconsetDirectory.appendingPathComponent(iconSize.filename))
}

try? FileManager.default.removeItem(at: icnsURL)
try runIconutil()

private func writePNG(size: Int, to url: URL, background: CGColor? = nil) throws {
    guard let image = renderIcon(size: size, background: background) else {
        throw NSError(domain: "VeilIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render icon image."])
    }

    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "VeilIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG destination."])
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "VeilIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to write PNG at \(url.path)."])
    }
}

private func runIconutil() throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["--convert", "icns", "--output", icnsURL.path, iconsetDirectory.path]

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw NSError(domain: "VeilIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed."])
    }
}

private func renderIcon(size: Int, background: CGColor? = nil) -> CGImage? {
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    context.interpolationQuality = .high
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    if let background {
        context.setFillColor(background)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    }

    let scale = CGFloat(size) / 1024.0
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: 0, y: 1024)
    context.scaleBy(x: 1, y: -1)

    drawIcon(in: context)
    return context.makeImage()
}

private func drawIcon(in context: CGContext) {
    let tileRect = CGRect(x: 96, y: 96, width: 832, height: 832)
    let tilePath = CGPath(roundedRect: tileRect, cornerWidth: 184, cornerHeight: 184, transform: nil)

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    drawLinearGradient(
        context,
        colors: [color(0xFCFBF6), color(0xF2F0E9), color(0xE2DFD5)],
        locations: [0, 0.54, 1],
        start: CGPoint(x: 276, y: 108),
        end: CGPoint(x: 748, y: 916)
    )
    context.restoreGState()

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    context.move(to: CGPoint(x: 256, y: 518))
    context.addLine(to: CGPoint(x: 768, y: 518))
    context.setStrokeColor(color(0xD8D5CB, alpha: 0.42))
    context.setLineWidth(2)
    context.setLineCap(.round)
    context.strokePath()

    strokeRoundedRect(context, rect: tileRect, radius: 184, color: color(0xFFFFFF, alpha: 0.72), width: 2)
    strokeRoundedRect(context, rect: tileRect, radius: 184, color: color(0x2C2D2A, alpha: 0.10), width: 2)
    context.restoreGState()

    drawCapsule(in: context)
}

private func drawCapsule(in context: CGContext) {
    let capsuleRect = CGRect(x: 246, y: 290, width: 532, height: 156)
    let capsulePath = CGPath(roundedRect: capsuleRect, cornerWidth: 78, cornerHeight: 78, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 16), blur: 18, color: color(0x000000, alpha: 0.22))
    context.addPath(capsulePath)
    context.clip()
    drawLinearGradient(
        context,
        colors: [color(0x161818), color(0x020303)],
        locations: [0, 1],
        start: CGPoint(x: 512, y: 248),
        end: CGPoint(x: 512, y: 444)
    )
    context.restoreGState()

    strokeRoundedRect(context, rect: capsuleRect.insetBy(dx: 1.5, dy: 1.5), radius: 76.5, color: color(0xFFFFFF, alpha: 0.11), width: 3)
    fillRoundedRect(context, rect: CGRect(x: 326, y: 360, width: 112, height: 18), radius: 9, color: color(0xF8F6EF, alpha: 0.88))
    fillRoundedRect(context, rect: CGRect(x: 586, y: 360, width: 112, height: 18), radius: 9, color: color(0xC7921E, alpha: 0.96))
    fillRoundedRect(context, rect: CGRect(x: 474, y: 348, width: 76, height: 42), radius: 21, color: color(0x000000, alpha: 0.72))
}

private func fillRoundedRect(_ context: CGContext, rect: CGRect, radius: CGFloat, color fillColor: CGColor) {
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.setFillColor(fillColor)
    context.fillPath()
}

private func strokeRoundedRect(_ context: CGContext, rect: CGRect, radius: CGFloat, color strokeColor: CGColor, width: CGFloat) {
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.setStrokeColor(strokeColor)
    context.setLineWidth(width)
    context.strokePath()
}

private func drawLinearGradient(
    _ context: CGContext,
    colors: [CGColor],
    locations: [CGFloat],
    start: CGPoint,
    end: CGPoint
) {
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else { return }
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
}

private func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    let red = CGFloat((hex >> 16) & 0xFF) / 255
    let green = CGFloat((hex >> 8) & 0xFF) / 255
    let blue = CGFloat(hex & 0xFF) / 255
    return CGColor(red: red, green: green, blue: blue, alpha: alpha)
}
