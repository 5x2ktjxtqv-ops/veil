import AppKit
import SwiftUI

@MainActor
final class OverlayHUDController {
    private static let defaultNotchWidth = NotchCapsuleLayout.referenceNotchVoidWidth
    private static let notchSideOverhang = NotchCapsuleLayout.defaultSideOverhang

    private let store: StatusStore
    private let panel: HUDPanel
    private let clickThrough: Bool
    private let configuration: StatusHUDConfiguration
    private var contentConfiguration: StatusHUDConfiguration?

    init(
        store: StatusStore,
        clickThrough: Bool,
        configuration: StatusHUDConfiguration = .productionCompact
    ) {
        self.store = store
        self.clickThrough = clickThrough
        self.configuration = configuration
        self.panel = HUDPanel(
            contentRect: NSRect(origin: .zero, size: configuration.size()),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
    }

    func show() {
        guard canDisplayHUD else {
            panel.orderOut(nil)
            return
        }

        reposition()
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    func reposition() {
        guard let screen = targetScreen() else {
            panel.orderOut(nil)
            return
        }

        let size = hudSize(on: screen)
        let origin = hudOrigin(on: screen, size: size)
        let frame = pixelAlignedFrame(
            NSRect(origin: origin, size: size),
            on: screen
        )

        updateContentConfiguration(for: frame.size)
        panel.setFrame(frame, display: true)
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.canHide = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = clickThrough
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        updateContentConfiguration(for: configuration.size())
    }

    private func updateContentConfiguration(for size: NSSize) {
        let resolvedConfiguration = configuration.withSize(size)
        guard contentConfiguration != resolvedConfiguration else { return }

        contentConfiguration = resolvedConfiguration
        panel.contentView = NSHostingView(
            rootView: StatusHUDView(store: store, configuration: resolvedConfiguration)
        )
    }

    private func targetScreen() -> NSScreen? {
        let notchScreen = NSScreen.screens.first { screen in
            screen.safeAreaInsets.top > 0
        }

        if configuration.mode == .notchCapsule,
           !configuration.showsSignals {
            return notchScreen
        }

        return notchScreen ?? NSScreen.main ?? NSScreen.screens.first
    }

    private var canDisplayHUD: Bool {
        targetScreen() != nil
    }

    private func hudOrigin(on screen: NSScreen, size: NSSize) -> NSPoint {
        if configuration.mode == .notchCapsule,
           let notchFrame = notchFrame(on: screen) {
            return NSPoint(
                x: notchFrame.midX - size.width / 2.0,
                y: screen.frame.maxY - size.height
            )
        }

        if let rightAuxiliaryArea = screen.auxiliaryTopRightArea,
           screen.safeAreaInsets.top > 0 {
            return rightAuxiliaryOrigin(
                in: rightAuxiliaryArea,
                size: size
            )
        }

        return NSPoint(
            x: screen.frame.maxX - size.width - 12.0,
            y: screen.frame.maxY - size.height - 4.0
        )
    }

    private func rightAuxiliaryOrigin(in area: NSRect, size: NSSize) -> NSPoint {
        let preferredInset: CGFloat = 2.0
        let x: CGFloat

        if area.width >= size.width + preferredInset * 2.0 {
            x = area.minX + preferredInset
        } else {
            x = area.midX - size.width / 2.0
        }

        return NSPoint(
            x: x,
            y: area.midY - size.height / 2.0
        )
    }

    private func hudSize(on screen: NSScreen) -> NSSize {
        guard configuration.mode == .notchCapsule,
              let notchFrame = notchFrame(on: screen) else {
            return configuration.size()
        }

        return NSSize(
            width: max(
                ceil(notchFrame.width + OverlayHUDController.notchSideOverhang * 2.0),
                configuration.width
            ),
            height: NotchCapsuleScreenGeometry.coverageHeight(
                on: screen,
                minimumHeight: configuration.height
            )
        )
    }

    private func notchFrame(on screen: NSScreen) -> NSRect? {
        guard screen.safeAreaInsets.top > 0 else { return nil }

        let notchWidth: CGFloat
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            notchWidth = max(rightArea.minX - leftArea.maxX, OverlayHUDController.defaultNotchWidth)
        } else {
            notchWidth = OverlayHUDController.defaultNotchWidth
        }

        let height = NotchCapsuleScreenGeometry.coverageHeight(
            on: screen,
            minimumHeight: configuration.height
        )
        return NSRect(
            x: screen.frame.midX - notchWidth / 2.0,
            y: screen.frame.maxY - height,
            width: notchWidth,
            height: height
        )
    }

    private func pixelAlignedFrame(_ frame: NSRect, on screen: NSScreen) -> NSRect {
        let scale = max(screen.backingScaleFactor, 1.0)

        func floorToPixel(_ value: CGFloat) -> CGFloat {
            floor(value * scale) / scale
        }

        func ceilToPixel(_ value: CGFloat) -> CGFloat {
            ceil(value * scale) / scale
        }

        let minX = floorToPixel(frame.minX)
        let minY = floorToPixel(frame.minY)
        let maxX = ceilToPixel(frame.maxX)
        let maxY = ceilToPixel(frame.maxY)

        return NSRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
}

enum NotchCapsuleScreenGeometry {
    static func coverageHeight(on screen: NSScreen, minimumHeight: CGFloat) -> CGFloat {
        coverageHeight(
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            safeAreaInsets: screen.safeAreaInsets,
            minimumHeight: minimumHeight
        )
    }

    static func coverageHeight(
        frame: NSRect,
        visibleFrame: NSRect,
        safeAreaInsets: NSEdgeInsets,
        minimumHeight: CGFloat
    ) -> CGFloat {
        let visibleTopInset = max(frame.maxY - visibleFrame.maxY, 0)
        return max(safeAreaInsets.top, visibleTopInset, minimumHeight)
    }
}

private extension StatusHUDConfiguration {
    func size() -> NSSize {
        NSSize(width: width, height: height)
    }
}

@MainActor
final class TopFusionBarController {
    private var windows: [NSWindow] = []

    func show() {
        rebuild()
    }

    func rebuild() {
        windows.forEach { $0.close() }
        windows = []
    }
}

@MainActor
final class BottomCornerMaskController {
    private static let hideDebounceDuration: Duration = .milliseconds(650)

    private let configuration: BottomCornerMaskConfiguration
    private var windows: [PassthroughWindow] = []
    private var isDisplayed = true
    private var pendingHideTask: Task<Void, Never>?

    init(configuration: BottomCornerMaskConfiguration) {
        self.configuration = configuration
    }

    func show() {
        rebuild()
        refreshVisibility()
    }

    func rebuild() {
        pendingHideTask?.cancel()
        pendingHideTask = nil
        windows.forEach { $0.close() }
        windows = targetScreens().flatMap { screen in
            [
                makeWindow(on: screen, corner: .bottomLeft),
                makeWindow(on: screen, corner: .bottomRight)
            ]
        }
        windows.forEach { window in
            window.alphaValue = isDisplayed ? 1 : 0
            if isDisplayed {
                window.orderFrontRegardless()
            }
        }
    }

    func refreshVisibility() {
        if isFullscreenCovered() {
            scheduleHideIfStillCovered()
        } else {
            pendingHideTask?.cancel()
            pendingHideTask = nil
            setDisplayed(true)
        }
    }

    func activeSpaceDidChange() {
        pendingHideTask?.cancel()
        pendingHideTask = nil
        orderFrontIfDisplayed()
        refreshVisibility()

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            self?.orderFrontIfDisplayed()
            self?.refreshVisibility()
        }
    }

    private func isFullscreenCovered() -> Bool {
        BottomCornerFullscreenDetector.frontmostWindowCoversAnyTargetDisplay(
            excludingProcessIdentifier: ProcessInfo.processInfo.processIdentifier,
            targetScreens: targetScreens()
        )
    }

    private func scheduleHideIfStillCovered() {
        guard pendingHideTask == nil, isDisplayed else { return }

        pendingHideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: BottomCornerMaskController.hideDebounceDuration)
            guard !Task.isCancelled, let self else { return }

            self.pendingHideTask = nil
            if self.isFullscreenCovered() {
                self.setDisplayed(false)
            }
        }
    }

    private func orderFrontIfDisplayed() {
        guard isDisplayed else { return }

        windows.forEach { window in
            window.orderFrontRegardless()
        }
    }

    private func setDisplayed(_ displayed: Bool) {
        guard displayed != isDisplayed else { return }
        isDisplayed = displayed

        windows.forEach { window in
            window.alphaValue = displayed ? 1 : 0
            if displayed {
                window.orderFrontRegardless()
            } else {
                window.orderOut(nil)
            }
        }
    }

    private func makeWindow(on screen: NSScreen, corner: BottomCornerMaskCorner) -> PassthroughWindow {
        let radius = CGFloat(configuration.radius)
        let frame = bottomCornerMaskFrame(on: screen, corner: corner, radius: radius)
        let window = PassthroughWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.canHide = false
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        window.contentView = BottomCornerMaskView(
            corner: corner,
            size: frame.size,
            cornerRadius: radius,
            backingScale: screen.backingScaleFactor
        )
        return window
    }

    private func targetScreens() -> [NSScreen] {
        NSScreen.screens.filter { screen in
            screen.safeAreaInsets.top > 0
                && screen.auxiliaryTopLeftArea != nil
                && screen.auxiliaryTopRightArea != nil
        }
    }

    private func pixelAlignedFrame(_ frame: NSRect, on screen: NSScreen) -> NSRect {
        let scale = max(screen.backingScaleFactor, 1.0)

        func floorToPixel(_ value: CGFloat) -> CGFloat {
            floor(value * scale) / scale
        }

        func ceilToPixel(_ value: CGFloat) -> CGFloat {
            ceil(value * scale) / scale
        }

        let minX = floorToPixel(frame.minX)
        let minY = floorToPixel(frame.minY)
        let maxX = ceilToPixel(frame.maxX)
        let maxY = ceilToPixel(frame.maxY)

        return NSRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    private func bottomCornerMaskFrame(
        on screen: NSScreen,
        corner: BottomCornerMaskCorner,
        radius: CGFloat
    ) -> NSRect {
        let scale = max(screen.backingScaleFactor, 1.0)
        let bleed = 1.0 / scale
        let side = ceil((radius + bleed) * scale) / scale
        let x = corner == .bottomLeft ? screen.frame.minX : screen.frame.maxX - side

        return NSRect(
            x: x,
            y: screen.frame.minY,
            width: side,
            height: side
        )
    }
}

enum BottomCornerMaskCorner {
    case bottomLeft
    case bottomRight
}

final class BottomCornerMaskView: NSImageView {
    init(
        corner: BottomCornerMaskCorner,
        size: NSSize,
        cornerRadius: CGFloat? = nil,
        backingScale: CGFloat
    ) {
        super.init(frame: NSRect(origin: .zero, size: size))
        image = BottomCornerMaskRenderer.renderMaskImage(
            corner: corner,
            size: size,
            cornerRadius: cornerRadius,
            backingScale: backingScale
        )
        imageAlignment = .alignCenter
        imageScaling = .scaleProportionallyDown
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isOpaque: Bool {
        false
    }
}

enum BottomCornerMaskRenderer {
    static let supersampleScale = 4

    static func renderMaskImage(
        corner: BottomCornerMaskCorner,
        size: NSSize,
        cornerRadius: CGFloat? = nil,
        backingScale: CGFloat
    ) -> NSImage {
        guard let cgImage = renderMaskCGImage(
            corner: corner,
            size: size,
            cornerRadius: cornerRadius,
            backingScale: backingScale
        ) else {
            return NSImage(size: size)
        }

        let representation = NSBitmapImageRep(cgImage: cgImage)
        representation.size = size

        let image = NSImage(size: size)
        image.addRepresentation(representation)
        return image
    }

    static func renderMaskCGImage(
        corner: BottomCornerMaskCorner,
        size: NSSize,
        cornerRadius: CGFloat? = nil,
        backingScale: CGFloat
    ) -> CGImage? {
        let scale = max(backingScale, 1.0)
        let pixelWidth = max(Int(round(size.width * scale)), 1)
        let pixelHeight = max(Int(round(size.height * scale)), 1)
        let highResolutionScale = scale * CGFloat(supersampleScale)
        let highResolutionPixelWidth = pixelWidth * supersampleScale
        let highResolutionPixelHeight = pixelHeight * supersampleScale
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let highResolutionContext = CGContext(
            data: nil,
            width: highResolutionPixelWidth,
            height: highResolutionPixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        highResolutionContext.scaleBy(x: highResolutionScale, y: highResolutionScale)
        drawMaskPath(
            in: highResolutionContext,
            corner: corner,
            size: size,
            cornerRadius: cornerRadius
        )

        guard let highResolutionImage = highResolutionContext.makeImage(),
              let context = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo
              ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(
            highResolutionImage,
            in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        )

        return context.makeImage()
    }

    private static func drawMaskPath(
        in context: CGContext,
        corner: BottomCornerMaskCorner,
        size: NSSize,
        cornerRadius: CGFloat?
    ) {
        let bounds = CGRect(origin: .zero, size: size)
        let radius = min(cornerRadius ?? min(size.width, size.height), size.width, size.height)
        let ellipseRect: CGRect

        switch corner {
        case .bottomLeft:
            ellipseRect = CGRect(x: 0, y: 0, width: radius * 2.0, height: radius * 2.0)
        case .bottomRight:
            ellipseRect = CGRect(
                x: size.width - radius * 2.0,
                y: 0,
                width: radius * 2.0,
                height: radius * 2.0
            )
        }

        context.setFillColor(VeilHardwareBlack.cgColor)
        context.addRect(bounds)
        context.addEllipse(in: ellipseRect)
        context.fillPath(using: .evenOdd)
    }
}

enum BottomCornerFullscreenDetector {
    static func frontmostWindowCoversAnyTargetDisplay(
        excludingProcessIdentifier ownProcessIdentifier: pid_t,
        targetScreens: [NSScreen]
    ) -> Bool {
        guard !targetScreens.isEmpty,
              let frontmostProcessIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              frontmostProcessIdentifier != ownProcessIdentifier else {
            return false
        }

        let targetDisplayBounds = targetScreens.flatMap { displayCandidateBounds(for: $0) }
        guard !targetDisplayBounds.isEmpty else { return false }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        for window in windowList {
            guard
                let ownerPID = window[kCGWindowOwnerPID as String] as? NSNumber,
                ownerPID.int32Value == Int32(frontmostProcessIdentifier),
                let layer = window[kCGWindowLayer as String] as? NSNumber,
                layer.intValue == 0,
                let alpha = window[kCGWindowAlpha as String] as? NSNumber,
                alpha.doubleValue > 0,
                let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
                let windowBounds = CGRect(dictionaryRepresentation: boundsDictionary)
            else {
                continue
            }

            if targetDisplayBounds.contains(where: { windowCoversDisplay(windowBounds: windowBounds, displayBounds: $0) }) {
                return true
            }
        }

        return false
    }

    static func windowCoversDisplay(
        windowBounds: CGRect,
        displayBounds: CGRect,
        tolerance: CGFloat = 2.0
    ) -> Bool {
        windowBounds.minX <= displayBounds.minX + tolerance
            && windowBounds.minY <= displayBounds.minY + tolerance
            && windowBounds.maxX >= displayBounds.maxX - tolerance
            && windowBounds.maxY >= displayBounds.maxY - tolerance
    }

    private static func displayCandidateBounds(for screen: NSScreen) -> [CGRect] {
        var bounds = [screen.frame]
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return bounds
        }

        let cgDisplayBounds = CGDisplayBounds(CGDirectDisplayID(displayID.uint32Value))
        if !bounds.contains(cgDisplayBounds) {
            bounds.append(cgDisplayBounds)
        }

        return bounds
    }
}

@MainActor
final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PassthroughWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
