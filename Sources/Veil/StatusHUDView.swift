import SwiftUI

enum StatusHUDMode: Equatable {
    case compact
    case expanded
    case statusItem
    case notchCapsule
}

struct NotchIslandStyle: Equatable {
    var screenInsetWidth: CGFloat
    var screenCornerWidth: CGFloat
    var screenCornerHeight: CGFloat
    var screenCornerControl: CGFloat
    var bottomCornerWidth: CGFloat
    var bottomCornerHeight: CGFloat
    var bottomCornerControl: CGFloat

    static let nativeSoft = NotchIslandStyle(
        screenInsetWidth: 30,
        screenCornerWidth: 4.5,
        screenCornerHeight: 5.5,
        screenCornerControl: 0.50,
        bottomCornerWidth: 14,
        bottomCornerHeight: 9,
        bottomCornerControl: 0.78
    )
}

struct StatusHUDConfiguration: Equatable {
    var mode: StatusHUDMode
    var width: CGFloat
    var height: CGFloat
    var notchStyle: NotchIslandStyle = .nativeSoft
    var showsSignals: Bool = true

    static let compact240 = StatusHUDConfiguration(mode: .compact, width: 240, height: 34)
    static let compact340 = StatusHUDConfiguration(mode: .compact, width: 340, height: 34)
    static let expanded420 = StatusHUDConfiguration(mode: .expanded, width: 420, height: 54)
    static let notchCapsule = StatusHUDConfiguration(mode: .notchCapsule, width: NotchCapsuleLayout.defaultWidth, height: 32)

    static let productionCompact = notchCapsule

    func withSize(_ size: CGSize) -> StatusHUDConfiguration {
        var resolved = self
        resolved.width = size.width
        resolved.height = size.height
        return resolved
    }

    func withSignals(_ showsSignals: Bool) -> StatusHUDConfiguration {
        var resolved = self
        resolved.showsSignals = showsSignals
        return resolved
    }
}

struct StatusHUDView: View {
    @ObservedObject private var store: StatusStore
    private let configuration: StatusHUDConfiguration

    init(
        store: StatusStore,
        configuration: StatusHUDConfiguration = .productionCompact
    ) {
        self.store = store
        self.configuration = configuration
    }

    var body: some View {
        StatusHUDSnapshotView(
            snapshot: store.renderedSnapshot,
            configuration: configuration
        )
    }
}

struct StatusHUDSnapshotView: View {
    var snapshot: VeilSnapshot
    var configuration: StatusHUDConfiguration = .productionCompact
    var fixedNotchLane: NotchCapsuleLaneID?

    var body: some View {
        if configuration.mode == .notchCapsule {
            notchCapsuleBody
        } else if configuration.mode == .statusItem {
            statusItemBody
        } else {
            hudBody
        }
    }

    private var hudBody: some View {
        content
            .padding(.horizontal, 14)
            .frame(width: configuration.width, height: configuration.height)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.96))
            )
            .overlay(alignment: .top) {
                stateStrip
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
    }

    @ViewBuilder
    private var statusItemBody: some View {
        if configuration.showsSignals {
            HStack(spacing: 5) {
                StatusIcon(role: StatusHUDMapping.severity(for: snapshot))

                HStack(spacing: 8) {
                    ForEach(StatusHUDMapping.compactMetrics(for: snapshot, configuration: configuration)) { metric in
                        MetricText(metric: metric, fontSize: 11)
                    }
                }
                .layoutPriority(1)
            }
            .padding(.horizontal, 3)
            .frame(width: configuration.width, height: configuration.height)
        } else {
            Color.clear
                .frame(width: configuration.width, height: configuration.height)
        }
    }

    @ViewBuilder
    private var notchCapsuleBody: some View {
        if let fixedNotchLane {
            notchCapsuleContent(
                mapping: StatusHUDMapping.notchCapsuleMetrics(
                    for: snapshot,
                    lane: fixedNotchLane
                )
            )
        } else {
            TimelineView(
                .periodic(
                    from: Date(timeIntervalSince1970: 0),
                    by: StatusHUDMapping.notchCapsuleLaneRotationInterval
                )
            ) { context in
                notchCapsuleContent(
                    mapping: StatusHUDMapping.notchCapsuleMetrics(
                        for: snapshot,
                        at: context.date
                    )
                )
            }
        }
    }

    private func notchCapsuleContent(mapping: NotchCapsuleHUDMapping) -> some View {
        let wingWidth = NotchCapsuleLayout.wingWidth(for: configuration.width)
        let notchVoidWidth = NotchCapsuleLayout.notchVoidWidth(for: configuration.width)
        let leftWing = configuration.showsSignals ? mapping.leftWing : []
        let rightWing = configuration.showsSignals ? mapping.rightWing : []

        return HStack(spacing: 0) {
            notchCapsuleWing(
                metrics: leftWing
            )
            .frame(width: wingWidth, alignment: .leading)

            Color.clear
                .frame(width: notchVoidWidth)

            notchCapsuleWing(
                metrics: rightWing
            )
            .frame(width: wingWidth, alignment: .trailing)
        }
        .padding(.horizontal, NotchCapsuleLayout.minimumVisualMargin)
        .frame(width: configuration.width, height: configuration.height)
        .background {
            NotchIslandShape(style: configuration.notchStyle)
                .fill(VeilHardwareBlack.color, style: FillStyle(eoFill: false, antialiased: true))
                .overlay {
                    NotchIslandShape(style: configuration.notchStyle)
                        .stroke(
                            VeilHardwareBlack.color.opacity(VeilHardwareBlack.notchEdgeCoverageOpacity),
                            lineWidth: 1
                        )
                }
        }
        .overlay(alignment: .topLeading) {
            if configuration.showsSignals,
               let indicator = mapping.indicator(on: .left) {
                HUDIndicatorDot(indicator: indicator)
                    .padding(.top, HUDIndicatorDot.topPadding(for: configuration.notchStyle))
                    .padding(.leading, HUDIndicatorDot.sidePadding(for: configuration.notchStyle))
            }
        }
        .overlay(alignment: .topTrailing) {
            if configuration.showsSignals,
               let indicator = mapping.indicator(on: .right) {
                HUDIndicatorDot(indicator: indicator)
                    .padding(.top, HUDIndicatorDot.topPadding(for: configuration.notchStyle))
                    .padding(.trailing, HUDIndicatorDot.sidePadding(for: configuration.notchStyle))
            }
        }
    }

    private func notchCapsuleWing(
        metrics: [HUDMetric]
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(metrics) { metric in
                MetricText(metric: metric, fontSize: NotchCapsuleLayout.metricFontSize)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch configuration.mode {
        case .compact:
            if configuration.showsSignals {
                HStack(spacing: 12) {
                    ForEach(StatusHUDMapping.compactMetrics(for: snapshot, configuration: configuration)) { metric in
                        MetricText(metric: metric)
                    }
                }
            } else {
                EmptyView()
            }
        case .expanded:
            if configuration.showsSignals {
                VStack(spacing: 5) {
                    HStack(spacing: 12) {
                        ForEach(StatusHUDMapping.expandedRows(for: snapshot).first ?? []) { metric in
                            MetricText(metric: metric)
                        }
                    }

                    HStack(spacing: 12) {
                        ForEach(StatusHUDMapping.expandedRows(for: snapshot).dropFirst().first ?? []) { metric in
                            MetricText(metric: metric)
                        }
                    }
                }
            } else {
                EmptyView()
            }
        case .statusItem:
            EmptyView()
        case .notchCapsule:
            EmptyView()
        }
    }

    private var stateStrip: some View {
        let severity = configuration.showsSignals
            ? StatusHUDMapping.severity(for: snapshot)
            : HUDMetricRole.neutral

        return Rectangle()
            .fill(severityColor(severity))
            .frame(height: severity == .neutral ? 0 : 2)
    }

    private func severityColor(_ role: HUDMetricRole) -> Color {
        switch role {
        case .critical:
            return HUDColor.critical
        case .warning:
            return HUDColor.warning
        case .normal, .muted, .neutral:
            return .clear
        }
    }
}

enum NotchCapsuleLayout {
    static let minimumVisualMargin: CGFloat = 34
    static let referenceNotchVoidWidth: CGFloat = 180
    static let metricFontSize: CGFloat = 11
    static let referenceWingSafetyPadding: CGFloat = 2
    static let referenceWingWidth: CGFloat = 36

    static var defaultWidth: CGFloat {
        referenceNotchVoidWidth + (minimumVisualMargin + referenceWingWidth) * 2
    }

    static var defaultSideOverhang: CGFloat {
        (defaultWidth - referenceNotchVoidWidth) / 2
    }

    static func wingWidth(for totalWidth: CGFloat) -> CGFloat {
        let availableWidth = max(totalWidth - minimumVisualMargin * 2, 0)
        let availableWingWidth = max((availableWidth - referenceNotchVoidWidth) / 2, 0)
        return min(referenceWingWidth, availableWingWidth)
    }

    static func notchVoidWidth(for totalWidth: CGFloat) -> CGFloat {
        let availableWidth = max(totalWidth - minimumVisualMargin * 2, 0)
        let wingWidth = wingWidth(for: totalWidth)
        return max(availableWidth - wingWidth * 2, referenceNotchVoidWidth)
    }
}

enum StatusHUDFormatter {
    static func ram(_ memory: MemoryStatus) -> String {
        guard let usedBytes = memory.usedBytes else { return "--" }
        return ByteFormat.gigabytes(usedBytes)
    }

    static func swap(_ memory: MemoryStatus) -> String {
        guard let swapUsedBytes = memory.swapUsedBytes else { return "--" }
        return ByteFormat.gigabytes(swapUsedBytes, digits: 1)
    }

    static func vpn(_ vpn: VPNStatus) -> String {
        switch vpn.stability {
        case .connectedHealthy, .connectedDegraded:
            return vpn.cityCode ?? vpn.countryCode ?? "ON"
        case .flapping:
            return "FLAP"
        case .connectingTransient:
            return "..."
        case .disconnected:
            return "OFF"
        case .cliUnavailableOrError:
            return "ERR"
        case .approvalRequired, .approvalDenied, .unknown:
            return "--"
        }
    }

    static func latency(_ vpn: VPNStatus) -> String? {
        guard let latencyMs = vpn.latencyMs else { return nil }
        return "\(Int(latencyMs.rounded()))ms"
    }

    static func download(_ snapshot: VeilSnapshot) -> String? {
        let downloadMbps = snapshot.vpn.downloadMbps ?? snapshot.network.downloadMbps
        return throughput(downloadMbps)
    }

    static func networkDownload(_ network: NetworkThroughput) -> String {
        throughput(network.downloadMbps) ?? "--"
    }

    static func networkUpload(_ network: NetworkThroughput) -> String {
        throughput(network.uploadMbps) ?? "--"
    }

    static func vpnPathSpeed(_ vpn: VPNStatus) -> String? {
        switch vpn.pathSpeed.quality {
        case .idle:
            return "IDLE"
        case .failed:
            return probeFailureCode(vpn.pathSpeed.failureReason)
        case .normal, .slow, .unknown:
            guard let downloadMbps = vpn.pathSpeed.downloadMbps else { return nil }
            return throughput(downloadMbps)
        }
    }

    private static func probeFailureCode(_ reason: VPNPathSpeedFailureReason?) -> String {
        switch reason ?? .network {
        case .timeout:
            return "TMO"
        case .network:
            return "NET"
        case .httpStatus:
            return "HTTP"
        }
    }

    private static func throughput(_ downloadMbps: Double?) -> String? {
        guard let downloadMbps, downloadMbps.isFinite, downloadMbps >= 0 else { return nil }

        if downloadMbps < 0.995 {
            return "\(Int((downloadMbps * 1_000).rounded()))K"
        }

        return "\(Int(downloadMbps.rounded()))M"
    }

    static func cpuUsage(_ cpu: CPUStatus) -> String {
        guard let usagePercent = cpu.usagePercent, usagePercent.isFinite else { return "--" }
        return "\(Int(usagePercent.rounded()))%"
    }

    static func cpuTemperature(_ cpu: CPUStatus) -> String {
        guard let temperatureCelsius = cpu.temperatureCelsius, temperatureCelsius.isFinite else { return "--" }
        return "\(Int(temperatureCelsius.rounded()))C"
    }

    static func cpuThermalPressure(_ cpu: CPUStatus) -> String {
        switch cpu.thermalPressure {
        case .nominal:
            return "OK"
        case .fair:
            return "WARM"
        case .serious:
            return "HOT"
        case .critical:
            return "CRIT"
        case .unknown:
            return "--"
        }
    }
}

private struct MetricText: View {
    var metric: HUDMetric
    var fontSize: CGFloat = 12

    var body: some View {
        HStack(spacing: 4) {
            if !metric.label.isEmpty {
                Text(metric.label)
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            Text(metric.value)
                .foregroundStyle(valueColor)
        }
        .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
        .lineLimit(1)
        .minimumScaleFactor(0.9)
    }

    private var valueColor: Color {
        switch metric.role {
        case .normal, .neutral:
            return Color.white.opacity(0.88)
        case .muted:
            return Color.white.opacity(0.48)
        case .warning:
            return HUDColor.warning
        case .critical:
            return HUDColor.critical
        }
    }
}

private struct StatusIcon: View {
    var role: HUDMetricRole

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 12, height: 12)
            .accessibilityHidden(true)
    }

    private var symbol: String {
        switch role {
        case .critical:
            return "xmark.octagon.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .muted:
            return "questionmark.circle.fill"
        case .normal, .neutral:
            return "circle.fill"
        }
    }

    private var symbolSize: CGFloat {
        switch role {
        case .critical, .warning:
            return 10
        case .normal, .muted, .neutral:
            return 8
        }
    }

    private var color: Color {
        switch role {
        case .critical:
            return HUDColor.critical
        case .warning:
            return HUDColor.warning
        case .muted:
            return Color.white.opacity(0.42)
        case .normal, .neutral:
            return HUDColor.healthy
        }
    }
}

private struct HUDIndicatorDot: View {
    static let diameter: CGFloat = 6
    private static let arcExteriorOffset = CGSize(width: -1, height: 1)

    var indicator: HUDIndicator

    static func topPadding(for style: NotchIslandStyle) -> CGFloat {
        max(style.screenCornerHeight - diameter / 2 + arcExteriorOffset.height, 0)
    }

    static func sidePadding(for style: NotchIslandStyle) -> CGFloat {
        max(style.screenInsetWidth - style.screenCornerWidth - diameter / 2 + arcExteriorOffset.width, 0)
    }

    @ViewBuilder
    var body: some View {
        if indicator.pulse == .none {
            dot(at: Date(timeIntervalSince1970: 0))
        } else {
            TimelineView(.periodic(from: Date(timeIntervalSince1970: 0), by: 1.0)) { context in
                dot(at: context.date)
            }
        }
    }

    private func dot(at date: Date) -> some View {
        Circle()
            .fill(color)
            .frame(width: Self.diameter, height: Self.diameter)
            .shadow(
                color: color.opacity(glowOpacity(at: date)),
                radius: glowRadius(at: date)
            )
            .opacity(dotOpacity(at: date))
            .accessibilityHidden(true)
    }

    private var color: Color {
        switch indicator.color {
        case .green:
            return HUDColor.trafficLightGreen
        case .yellow:
            return HUDColor.trafficLightYellow
        case .red:
            return HUDColor.trafficLightRed
        case .muted:
            return Color.white.opacity(0.42)
        }
    }

    private func dotOpacity(at date: Date) -> Double {
        guard indicator.pulse != .none else {
            return indicator.steadyOpacity ?? 0.42
        }

        let wave = breathWave(at: date, cycle: indicator.pulse.cycleDuration)

        switch indicator.color {
        case .green:
            return 0.94 + wave * 0.06
        case .yellow:
            return 0.9 + wave * 0.1
        case .red:
            return 0.9 + wave * 0.1
        case .muted:
            return indicator.steadyOpacity ?? 0.42
        }
    }

    private func glowOpacity(at date: Date) -> Double {
        guard indicator.pulse != .none else { return 0 }

        let wave = breathWave(at: date, cycle: indicator.pulse.cycleDuration)

        switch indicator.color {
        case .green:
            return 0.38 + wave * 0.34
        case .yellow:
            return 0.46 + wave * 0.42
        case .red:
            return 0.24 + wave * 0.36
        case .muted:
            return 0
        }
    }

    private func glowRadius(at date: Date) -> CGFloat {
        guard indicator.pulse != .none else { return 0 }

        let wave = breathWave(at: date, cycle: indicator.pulse.cycleDuration)

        switch indicator.color {
        case .green:
            return CGFloat(1.1 + wave * 1.4)
        case .yellow:
            return CGFloat(1.3 + wave * 2.4)
        case .red:
            return CGFloat(0.8 + wave * 1.2)
        case .muted:
            return 0
        }
    }

    private func breathWave(at date: Date, cycle: TimeInterval) -> Double {
        guard cycle > 0 else {
            return 0
        }

        let progress = date.timeIntervalSince1970
            .truncatingRemainder(dividingBy: cycle) / cycle
        let triangle = progress <= 0.5 ? progress * 2 : (1 - progress) * 2
        return triangle * triangle * (3 - 2 * triangle)
    }
}

private struct NotchIslandShape: Shape {
    var style: NotchIslandStyle

    func path(in rect: CGRect) -> Path {
        let screenInsetWidth = min(style.screenInsetWidth, rect.width / 3)
        let bottomCornerHeight = min(style.bottomCornerHeight, rect.height / 2, rect.width / 4)
        let bottomCornerWidth = min(style.bottomCornerWidth, rect.width / 4)
        let screenCornerWidth = min(style.screenCornerWidth, screenInsetWidth, rect.width / 4)
        let screenCornerHeight = min(style.screenCornerHeight, max(rect.height - bottomCornerHeight - 1, 0))
        let leftSide = rect.minX + screenInsetWidth
        let rightSide = rect.maxX - screenInsetWidth
        let sideStartY = rect.minY + screenCornerHeight
        let bottomStartY = rect.maxY - bottomCornerHeight
        let screenCornerControlX = screenCornerWidth * style.screenCornerControl
        let screenCornerControlY = screenCornerHeight * style.screenCornerControl
        let bottomCornerControlX = bottomCornerWidth * style.bottomCornerControl
        let bottomCornerControlY = bottomCornerHeight * style.bottomCornerControl

        var path = Path()
        path.move(to: CGPoint(x: leftSide - screenCornerWidth, y: rect.minY))
        path.addLine(to: CGPoint(x: rightSide + screenCornerWidth, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rightSide, y: sideStartY),
            control1: CGPoint(x: rightSide + screenCornerWidth - screenCornerControlX, y: rect.minY),
            control2: CGPoint(x: rightSide, y: sideStartY - screenCornerControlY)
        )
        path.addLine(to: CGPoint(x: rightSide, y: bottomStartY))
        path.addCurve(
            to: CGPoint(x: rightSide - bottomCornerWidth, y: rect.maxY),
            control1: CGPoint(x: rightSide, y: bottomStartY + bottomCornerControlY),
            control2: CGPoint(x: rightSide - bottomCornerWidth + bottomCornerControlX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: leftSide + bottomCornerWidth, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: leftSide, y: bottomStartY),
            control1: CGPoint(x: leftSide + bottomCornerWidth - bottomCornerControlX, y: rect.maxY),
            control2: CGPoint(x: leftSide, y: bottomStartY + bottomCornerControlY)
        )
        path.addLine(to: CGPoint(x: leftSide, y: sideStartY))
        path.addCurve(
            to: CGPoint(x: leftSide - screenCornerWidth, y: rect.minY),
            control1: CGPoint(x: leftSide, y: sideStartY - screenCornerControlY),
            control2: CGPoint(x: leftSide - screenCornerWidth + screenCornerControlX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private enum HUDColor {
    static let healthy = Color(red: 0.36, green: 0.72, blue: 0.48)
    static let warning = Color(red: 0.85, green: 0.62, blue: 0.18)
    static let critical = Color(red: 0.88, green: 0.24, blue: 0.19)
    static let trafficLightRed = Color(red: 1.0, green: 0.37, blue: 0.34)
    static let trafficLightYellow = Color(red: 1.0, green: 0.74, blue: 0.18)
    static let trafficLightGreen = Color(red: 0.16, green: 0.78, blue: 0.25)
}
