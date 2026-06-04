import Foundation

struct NotchCapsuleHUDMapping: Equatable {
    var lane: NotchCapsuleLaneID
    var source: String
    var leftWing: [HUDMetric]
    var notchVoid: [HUDMetric]
    var rightWing: [HUDMetric]
    var severity: HUDMetricRole
    var indicators: [HUDIndicatorSlot]

    var indicator: HUDIndicator? {
        indicator(on: .left)
    }

    func indicator(on side: HUDIndicatorSide) -> HUDIndicator? {
        indicators.first(where: { $0.side == side })?.indicator
    }
}

struct NotchCapsuleLaneID: RawRepresentable, Hashable, Equatable, Sendable, ExpressibleByStringLiteral {
    var rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        self.rawValue = value
    }

    static let vpn = NotchCapsuleLaneID("vpn")
    static let memory = NotchCapsuleLaneID("memory")
    static let cpu = NotchCapsuleLaneID("cpu")
    static let network = NotchCapsuleLaneID("network")
    static let modelGrowthWorkload = NotchCapsuleLaneID("model-growth.workload")
}

enum StatusHUDMapping {
    static let notchCapsuleLaneRotationInterval: TimeInterval = 3
    private static let baseNotchCapsuleLaneIDs: [NotchCapsuleLaneID] = [.memory, .cpu, .network]

    static func notchCapsuleMetrics(for snapshot: VeilSnapshot) -> NotchCapsuleHUDMapping {
        notchCapsuleMetrics(for: snapshot, at: Date())
    }

    static func notchCapsuleMetrics(
        for snapshot: VeilSnapshot,
        at date: Date
    ) -> NotchCapsuleHUDMapping {
        let lanes = notchCapsuleLanes(for: snapshot)
        let selectedLane = notchCapsuleLane(in: lanes, at: date) ?? fallbackLane()
        return notchCapsuleMetrics(
            from: selectedLane,
            indicators: notchCapsuleIndicators(for: snapshot)
        )
    }

    static func notchCapsuleMetrics(
        for snapshot: VeilSnapshot,
        lane laneID: NotchCapsuleLaneID
    ) -> NotchCapsuleHUDMapping {
        let lane = notchCapsuleSignalGroups(for: snapshot)
            .flatMap(\.lanes)
            .first(where: { $0.id == laneID })
            ?? fallbackLane(for: laneID)
            ?? fallbackLane()
        return notchCapsuleMetrics(
            from: lane,
            indicators: notchCapsuleIndicators(for: snapshot)
        )
    }

    static func notchCapsuleLane(at date: Date) -> NotchCapsuleLaneID {
        notchCapsuleLaneID(in: baseNotchCapsuleLaneIDs, at: date)
    }

    static func notchCapsuleLane(
        for snapshot: VeilSnapshot,
        at date: Date
    ) -> NotchCapsuleLaneID {
        notchCapsuleLane(in: notchCapsuleLanes(for: snapshot), at: date)?.id ?? fallbackLane().id
    }

    static func notchCapsuleLanes(for snapshot: VeilSnapshot) -> [HUDLane] {
        allNotchCapsuleLanes(for: snapshot)
            .filter(\.isEnabled)
    }

    private static func allNotchCapsuleLanes(for snapshot: VeilSnapshot) -> [HUDLane] {
        notchCapsuleSignalGroups(for: snapshot)
            .filter(\.isEnabled)
            .flatMap(\.lanes)
    }

    static func notchCapsuleIndicators(for snapshot: VeilSnapshot) -> [HUDIndicatorSlot] {
        notchCapsuleSignalGroups(for: snapshot)
            .filter(\.isEnabled)
            .flatMap(\.indicators)
    }

    private static func notchCapsuleLane(
        in lanes: [HUDLane],
        at date: Date
    ) -> HUDLane? {
        guard !lanes.isEmpty else { return nil }
        let rawSlot = Int(floor(date.timeIntervalSince1970 / notchCapsuleLaneRotationInterval))
        let index = ((rawSlot % lanes.count) + lanes.count) % lanes.count
        return lanes[index]
    }

    private static func notchCapsuleLaneID(
        in laneIDs: [NotchCapsuleLaneID],
        at date: Date
    ) -> NotchCapsuleLaneID {
        guard !laneIDs.isEmpty else { return fallbackLane().id }
        let rawSlot = Int(floor(date.timeIntervalSince1970 / notchCapsuleLaneRotationInterval))
        let index = ((rawSlot % laneIDs.count) + laneIDs.count) % laneIDs.count
        return laneIDs[index]
    }

    private static func notchCapsuleMetrics(
        from lane: HUDLane,
        indicators: [HUDIndicatorSlot]
    ) -> NotchCapsuleHUDMapping {
        NotchCapsuleHUDMapping(
            lane: lane.id,
            source: lane.source,
            leftWing: lane.leftWing,
            notchVoid: lane.notchVoid,
            rightWing: lane.rightWing,
            severity: lane.severity,
            indicators: indicators
        )
    }

    private static func notchCapsuleSignalGroups(for snapshot: VeilSnapshot) -> [HUDSignalGroup] {
        var groups = [
            memorySignalGroup(for: snapshot),
            cpuSignalGroup(for: snapshot),
            networkSignalGroup(for: snapshot)
        ]

        groups.append(
            mullvadSignalGroup(
                for: snapshot,
                isEnabled: shouldShowMullvadSignalGroup(for: snapshot.vpn)
            )
        )

        groups.append(taskStatusSignalGroup(for: snapshot.taskStatus))

        if let modelGrowth = snapshot.modelGrowth {
            groups.append(modelGrowthSignalGroup(for: modelGrowth))
        }

        groups.append(powerKeepAliveSignalGroup(for: snapshot.powerKeepAlive))
        return groups
    }

    private static func mullvadSignalGroup(
        for snapshot: VeilSnapshot,
        isEnabled: Bool
    ) -> HUDSignalGroup {
        let metrics = vpnLaneMetrics(for: snapshot)
        return HUDSignalGroup(
            source: "mullvad",
            lanes: [
                pairedLane(
                    id: .vpn,
                    source: "mullvad",
                    metrics: metrics
                )
            ],
            indicators: [],
            isEnabled: isEnabled
        )
    }

    private static func memorySignalGroup(for snapshot: VeilSnapshot) -> HUDSignalGroup {
        let metrics = memoryLaneMetrics(for: snapshot)
        return HUDSignalGroup(
            source: "memory",
            lanes: [
                pairedLane(
                    id: .memory,
                    source: "memory",
                    metrics: metrics
                )
            ],
            indicators: []
        )
    }

    private static func cpuSignalGroup(for snapshot: VeilSnapshot) -> HUDSignalGroup {
        let metrics = cpuLaneMetrics(for: snapshot)
        return HUDSignalGroup(
            source: "cpu",
            lanes: [
                pairedLane(
                    id: .cpu,
                    source: "cpu",
                    metrics: metrics
                )
            ],
            indicators: []
        )
    }

    private static func networkSignalGroup(for snapshot: VeilSnapshot) -> HUDSignalGroup {
        let metrics = networkLaneMetrics(for: snapshot)
        return HUDSignalGroup(
            source: "network",
            lanes: [
                pairedLane(
                    id: .network,
                    source: "network",
                    metrics: metrics
                )
            ],
            indicators: []
        )
    }

    private static func modelGrowthSignalGroup(for status: ModelGrowthCompactStatus) -> HUDSignalGroup {
        HUDSignalGroup(
            source: "model-growth",
            lanes: ["workload"].map { fieldID in
                modelGrowthLane(for: status, fieldID: fieldID)
            },
            indicators: [
                HUDIndicatorSlot(
                    side: .left,
                    source: "model-growth",
                    indicator: modelGrowthIndicator(for: status.indicator.color)
                )
            ]
        )
    }

    private static func taskStatusSignalGroup(for status: TaskStatusSnapshot) -> HUDSignalGroup {
        HUDSignalGroup(
            source: "task-status",
            lanes: [],
            indicators: [
                HUDIndicatorSlot(
                    side: .left,
                    source: "task-status",
                    indicator: taskStatusIndicator(for: status)
                )
            ],
            isEnabled: status.state != .inactive
        )
    }

    private static func powerKeepAliveSignalGroup(for power: PowerKeepAliveSnapshot) -> HUDSignalGroup {
        HUDSignalGroup(
            source: "power-keepalive",
            lanes: [],
            indicators: [
                HUDIndicatorSlot(
                    side: .right,
                    source: "power-keepalive",
                    indicator: powerKeepAliveIndicator(for: power)
                )
            ],
            isEnabled: power.state != .inactive
        )
    }

    private static func pairedLane(
        id: NotchCapsuleLaneID,
        source: String,
        metrics: (left: HUDMetric, right: HUDMetric),
        isEnabled: Bool = true
    ) -> HUDLane {
        HUDLane(
            id: id,
            source: source,
            leftWing: [metrics.left],
            notchVoid: [],
            rightWing: [metrics.right],
            severity: severity(for: [metrics.left, metrics.right]),
            isEnabled: isEnabled
        )
    }

    private static func fallbackLane() -> HUDLane {
        pairedLane(
            id: "status.unavailable",
            source: "status",
            metrics: (
                HUDMetric(id: "status-left", label: "", value: "--", role: .muted),
                HUDMetric(id: "status-right", label: "", value: "--", role: .muted)
            )
        )
    }

    private static func fallbackLane(for laneID: NotchCapsuleLaneID) -> HUDLane? {
        guard let fieldID = modelGrowthFieldID(for: laneID) else { return nil }
        return modelGrowthLane(
            for: .unavailable(updatedAt: Date()),
            fieldID: fieldID
        )
    }

    static func compactMetrics(
        for snapshot: VeilSnapshot,
        configuration: StatusHUDConfiguration
    ) -> [HUDMetric] {
        if isApprovalNeeded(snapshot.vpn) {
            return [
                HUDMetric(id: "vpn-approval", label: "VPN", value: "APPROVAL", role: .warning)
            ]
        }

        if snapshot.vpn.errorReason == .approvalDenied {
            return compactPairWithRAM(
                HUDMetric(id: "vpn-restricted", label: "VPN", value: "--", role: .muted),
                snapshot: snapshot,
                configuration: configuration
            )
        }

        if snapshot.vpn.connection == .disconnected {
            return compactPairWithRAM(
                HUDMetric(id: "vpn-off", label: "VPN", value: "OFF", role: .critical),
                snapshot: snapshot,
                configuration: configuration
            )
        }

        if snapshot.memory.pressure == .high {
            return [
                HUDMetric(id: "mem-high", label: "MEM", value: "HIGH", role: .critical),
                HUDMetric(id: "swap-high", label: "SWAP", value: StatusHUDFormatter.swap(snapshot.memory), role: .critical)
            ]
        }

        if isLatencyDegraded(snapshot.vpn) {
            return [
                HUDMetric(id: "vpn", label: "VPN", value: StatusHUDFormatter.vpn(snapshot.vpn), role: .normal),
                HUDMetric(id: "latency", label: "", value: StatusHUDFormatter.latency(snapshot.vpn) ?? "--", role: .warning)
            ]
        }

        if snapshot.memory.pressure == .elevated {
            return [
                HUDMetric(id: "ram", label: "RAM", value: StatusHUDFormatter.ram(snapshot.memory), role: .warning),
                HUDMetric(id: "swap", label: "SWAP", value: StatusHUDFormatter.swap(snapshot.memory), role: .warning)
            ]
        }

        if isNetworkUnknown(snapshot) {
            return [
                HUDMetric(id: "ram", label: "RAM", value: StatusHUDFormatter.ram(snapshot.memory), role: .normal),
                HUDMetric(id: "net-unknown", label: "NET", value: "--", role: .muted)
            ]
        }

        return [
            HUDMetric(id: "ram", label: "RAM", value: StatusHUDFormatter.ram(snapshot.memory), role: .normal),
            HUDMetric(id: "vpn", label: "VPN", value: StatusHUDFormatter.vpn(snapshot.vpn), role: .normal)
        ]
    }

    static func expandedRows(for snapshot: VeilSnapshot) -> [[HUDMetric]] {
        [
            [
                HUDMetric(id: "ram", label: "RAM", value: StatusHUDFormatter.ram(snapshot.memory), role: memoryRole(for: snapshot)),
                HUDMetric(id: "swap", label: "SWAP", value: StatusHUDFormatter.swap(snapshot.memory), role: memoryRole(for: snapshot))
            ],
            expandedVPNMetrics(for: snapshot)
        ]
    }

    static func severity(for snapshot: VeilSnapshot) -> HUDMetricRole {
        let cpuSeverity = cpuSeverityRole(for: snapshot.cpu)
        let taskSeverity = taskStatusRole(for: snapshot.taskStatus)
        let powerSeverity = powerKeepAliveRole(for: snapshot.powerKeepAlive)

        if snapshot.memory.pressure == .high
            || cpuSeverity == .critical
            || taskSeverity == .critical
            || powerSeverity == .critical
            || snapshot.vpn.stability == .disconnected {
            return .critical
        }

        if snapshot.memory.pressure == .elevated
            || cpuSeverity == .warning
            || taskSeverity == .warning
            || powerSeverity == .warning
            || snapshot.vpn.stability == .flapping
            || snapshot.vpn.stability == .cliUnavailableOrError
            || isLatencyDegraded(snapshot.vpn) {
            return .warning
        }

        return .neutral
    }

    static func isNetworkUnknown(_ snapshot: VeilSnapshot) -> Bool {
        guard !isMullvadReadRestricted(snapshot.vpn) else { return false }

        let vpnUnknown = snapshot.vpn.connection == .unknown
            || snapshot.vpn.nodeHealth == .unknown
        let networkUnknown = snapshot.network.downloadMbps == nil
            && snapshot.network.uploadMbps == nil
            && snapshot.vpn.latencyMs == nil
            && snapshot.vpn.downloadMbps == nil

        return vpnUnknown && networkUnknown
    }

    static func isApprovalNeeded(_ vpn: VPNStatus) -> Bool {
        vpn.errorReason == .approvalRequired
    }

    static func isMullvadReadRestricted(_ vpn: VPNStatus) -> Bool {
        vpn.errorReason == .approvalRequired || vpn.errorReason == .approvalDenied
    }

    private static func shouldShowMullvadSignalGroup(for vpn: VPNStatus) -> Bool {
        !isMullvadReadRestricted(vpn)
            && (
                vpn.connection != .unknown
                    || vpn.countryCode != nil
                    || vpn.cityCode != nil
                    || vpn.latencyMs != nil
                    || vpn.downloadMbps != nil
                    || vpn.pathSpeed != .unknown
                    || vpn.errorReason != nil
            )
    }

    static func isLatencyDegraded(_ vpn: VPNStatus) -> Bool {
        if vpn.stability == .connectedDegraded {
            return true
        }

        guard vpn.connection == .connected else { return false }
        guard let latencyMs = vpn.latencyMs else { return false }
        return latencyMs >= VPNLatencyHealthThresholds.degradedMs
    }

    private static func expandedVPNMetrics(for snapshot: VeilSnapshot) -> [HUDMetric] {
        if isApprovalNeeded(snapshot.vpn) {
            return [
                HUDMetric(id: "vpn-approval", label: "VPN", value: "APPROVAL", role: .warning)
            ]
        }

        if snapshot.vpn.errorReason == .approvalDenied {
            return [
                HUDMetric(id: "vpn-restricted", label: "VPN", value: "--", role: .muted)
            ]
        }

        var metrics = [
            HUDMetric(id: "vpn", label: "VPN", value: StatusHUDFormatter.vpn(snapshot.vpn), role: vpnRole(for: snapshot))
        ]

        if let latency = StatusHUDFormatter.latency(snapshot.vpn) {
            metrics.append(
                HUDMetric(id: "latency", label: "", value: latency, role: latencyRole(for: snapshot))
            )
        }

        if let download = StatusHUDFormatter.download(snapshot) {
            metrics.append(
                HUDMetric(id: "download", label: "", value: download, role: .normal)
            )
        } else if isNetworkUnknown(snapshot) {
            metrics.append(
                HUDMetric(id: "net-unknown", label: "NET", value: "--", role: .muted)
            )
        }

        return metrics
    }

    private static func compactPairWithRAM(
        _ metric: HUDMetric,
        snapshot: VeilSnapshot,
        configuration: StatusHUDConfiguration
    ) -> [HUDMetric] {
        guard configuration.width > 240 else { return [metric] }

        return [
            HUDMetric(id: "ram", label: "RAM", value: StatusHUDFormatter.ram(snapshot.memory), role: .normal),
            metric
        ]
    }

    private static func vpnLaneMetrics(for snapshot: VeilSnapshot) -> (left: HUDMetric, right: HUDMetric) {
        let quality = vpnLaneQuality(for: snapshot)

        return (
            HUDMetric(
                id: "vpn-primary",
                label: "",
                value: StatusHUDFormatter.vpn(snapshot.vpn),
                role: vpnRole(for: snapshot)
            ),
            HUDMetric(
                id: "vpn-quality",
                label: "",
                value: quality.value,
                role: quality.role
            )
        )
    }

    private static func vpnLaneQuality(for snapshot: VeilSnapshot) -> (value: String, role: HUDMetricRole) {
        switch snapshot.vpn.stability {
        case .flapping:
            return ("\(max(snapshot.vpn.flapCount ?? 0, 1))x", .warning)
        case .connectedHealthy, .connectedDegraded:
            guard let pathSpeed = StatusHUDFormatter.vpnPathSpeed(snapshot.vpn) else {
                return ("--", .muted)
            }

            return (pathSpeed, vpnPathSpeedRole(for: snapshot.vpn))
        case .connectingTransient, .disconnected, .approvalRequired, .approvalDenied, .cliUnavailableOrError, .unknown:
            return ("--", .muted)
        }
    }

    private static func vpnPathSpeedRole(for vpn: VPNStatus) -> HUDMetricRole {
        switch vpn.pathSpeed.quality {
        case .normal:
            return .normal
        case .slow:
            return .warning
        case .failed:
            return .warning
        case .idle, .unknown:
            return .muted
        }
    }

    private static func memoryLaneMetrics(for snapshot: VeilSnapshot) -> (left: HUDMetric, right: HUDMetric) {
        (
            HUDMetric(
                id: "mem-primary",
                label: "",
                value: StatusHUDFormatter.ram(snapshot.memory),
                role: memoryRole(for: snapshot)
            ),
            HUDMetric(
                id: "mem-pressure",
                label: "",
                value: StatusHUDFormatter.swap(snapshot.memory),
                role: memoryRole(for: snapshot)
            )
        )
    }

    private static func cpuLaneMetrics(for snapshot: VeilSnapshot) -> (left: HUDMetric, right: HUDMetric) {
        (
            HUDMetric(
                id: "cpu-primary",
                label: "",
                value: StatusHUDFormatter.cpuUsage(snapshot.cpu),
                role: cpuUsageRole(for: snapshot.cpu)
            ),
            HUDMetric(
                id: "cpu-quality",
                label: "",
                value: StatusHUDFormatter.cpuThermalPressure(snapshot.cpu),
                role: cpuThermalPressureRole(for: snapshot.cpu)
            )
        )
    }

    private static func networkLaneMetrics(for snapshot: VeilSnapshot) -> (left: HUDMetric, right: HUDMetric) {
        (
            HUDMetric(
                id: "network-download",
                label: "",
                value: StatusHUDFormatter.networkDownload(snapshot.network),
                role: snapshot.network.downloadMbps == nil ? .muted : .normal
            ),
            HUDMetric(
                id: "network-upload",
                label: "",
                value: StatusHUDFormatter.networkUpload(snapshot.network),
                role: snapshot.network.uploadMbps == nil ? .muted : .normal
            )
        )
    }

    private static func modelGrowthLane(
        for status: ModelGrowthCompactStatus,
        fieldID: String
    ) -> HUDLane {
        let field = modelGrowthField(for: status, fieldID: fieldID)
        let role = modelGrowthFieldRole(for: field)

        return HUDLane(
            id: modelGrowthLaneID(for: fieldID),
            source: "model-growth",
            leftWing: [
                HUDMetric(
                    id: "model-growth-\(field.id)-left",
                    label: "",
                    value: field.left,
                    role: role
                )
            ],
            notchVoid: [],
            rightWing: [
                HUDMetric(
                    id: "model-growth-\(field.id)-right",
                    label: "",
                    value: field.right,
                    role: role
                )
            ],
            severity: modelGrowthSeverity(for: status.indicator.color)
        )
    }

    private static func modelGrowthField(
        for status: ModelGrowthCompactStatus,
        fieldID: String
    ) -> ModelGrowthCompactField {
        return status.fields.first(where: { $0.id == fieldID })
            ?? ModelGrowthCompactField(id: fieldID, left: "--", right: "--")
    }

    private static func modelGrowthLaneID(for fieldID: String) -> NotchCapsuleLaneID {
        switch fieldID {
        case "workload":
            return .modelGrowthWorkload
        default:
            return NotchCapsuleLaneID("model-growth.\(fieldID)")
        }
    }

    private static func modelGrowthFieldID(for laneID: NotchCapsuleLaneID) -> String? {
        switch laneID {
        case .modelGrowthWorkload:
            return "workload"
        default:
            return nil
        }
    }

    private static func modelGrowthIndicator(for color: ModelGrowthIndicatorColor) -> HUDIndicator {
        switch color {
        case .green:
            return HUDIndicator(color: .green, pulse: .none, steadyOpacity: 0.96)
        case .yellow:
            return HUDIndicator(color: .yellow, pulse: .medium)
        case .red:
            return HUDIndicator(color: .red, pulse: .fast)
        case .unknown:
            return HUDIndicator(color: .yellow, pulse: .medium)
        }
    }

    private static func taskStatusIndicator(for status: TaskStatusSnapshot) -> HUDIndicator {
        switch status.state {
        case .running:
            return HUDIndicator(color: .yellow, pulse: .medium)
        case .succeeded:
            return HUDIndicator(color: .green, pulse: .none, steadyOpacity: 0.96)
        case .failed:
            return HUDIndicator(color: .red, pulse: .fast)
        case .attention, .stale, .unknown:
            return HUDIndicator(color: .yellow, pulse: .fast)
        case .inactive:
            return HUDIndicator(color: .muted, pulse: .none, steadyOpacity: 0.24)
        }
    }

    private static func powerKeepAliveIndicator(for power: PowerKeepAliveSnapshot) -> HUDIndicator {
        switch power.state {
        case .verified:
            return HUDIndicator(color: .green, pulse: .none, steadyOpacity: 0.96)
        case .degraded:
            return HUDIndicator(color: .yellow, pulse: .medium)
        case .failed:
            return HUDIndicator(color: .red, pulse: .fast)
        case .asserted:
            return HUDIndicator(color: .green, pulse: .none, steadyOpacity: 0.96)
        case .inactive:
            return HUDIndicator(color: .muted, pulse: .none, steadyOpacity: 0.24)
        }
    }

    private static func severity(for metrics: [HUDMetric]) -> HUDMetricRole {
        if metrics.contains(where: { $0.role == .critical }) {
            return .critical
        }

        if metrics.contains(where: { $0.role == .warning }) {
            return .warning
        }

        return .neutral
    }

    private static func memoryRole(for snapshot: VeilSnapshot) -> HUDMetricRole {
        switch snapshot.memory.pressure {
        case .high:
            return .critical
        case .elevated:
            return .warning
        case .normal, .unknown:
            return .normal
        }
    }

    private static func vpnRole(for snapshot: VeilSnapshot) -> HUDMetricRole {
        switch snapshot.vpn.stability {
        case .connectedHealthy:
            return .normal
        case .connectedDegraded, .flapping, .cliUnavailableOrError:
            return .warning
        case .connectingTransient:
            return .normal
        case .disconnected:
            return .critical
        case .approvalRequired, .approvalDenied, .unknown:
            return .muted
        }
    }

    private static func latencyRole(for snapshot: VeilSnapshot) -> HUDMetricRole {
        snapshot.vpn.stability == .flapping || isLatencyDegraded(snapshot.vpn) ? .warning : .normal
    }

    private static func cpuUsageRole(for cpu: CPUStatus) -> HUDMetricRole {
        guard cpu.usagePercent != nil else { return .muted }

        switch cpu.usageHealth {
        case .high:
            return .critical
        case .elevated:
            return .warning
        case .normal, .unknown:
            return .normal
        }
    }

    private static func cpuSeverityRole(for cpu: CPUStatus) -> HUDMetricRole {
        mostSevere(cpuUsageRole(for: cpu), cpuThermalPressureRole(for: cpu))
    }

    private static func cpuThermalPressureRole(for cpu: CPUStatus) -> HUDMetricRole {
        switch cpu.thermalPressure {
        case .nominal:
            return .normal
        case .fair, .serious:
            return .warning
        case .critical:
            return .critical
        case .unknown:
            return .muted
        }
    }

    private static func mostSevere(_ lhs: HUDMetricRole, _ rhs: HUDMetricRole) -> HUDMetricRole {
        if lhs == .critical || rhs == .critical {
            return .critical
        }

        if lhs == .warning || rhs == .warning {
            return .warning
        }

        if lhs == .normal || rhs == .normal {
            return .normal
        }

        return .muted
    }

    private static func powerKeepAliveRole(for power: PowerKeepAliveSnapshot) -> HUDMetricRole {
        switch power.state {
        case .verified:
            return .normal
        case .degraded:
            return .warning
        case .failed:
            return .critical
        case .asserted, .inactive:
            return .muted
        }
    }

    private static func taskStatusRole(for status: TaskStatusSnapshot) -> HUDMetricRole {
        switch status.state {
        case .failed:
            return .critical
        case .attention, .stale, .unknown:
            return .warning
        case .running, .succeeded, .inactive:
            return .muted
        }
    }

    private static func modelGrowthSeverity(for color: ModelGrowthIndicatorColor) -> HUDMetricRole {
        switch color {
        case .green:
            return .neutral
        case .yellow, .unknown:
            return .warning
        case .red:
            return .critical
        }
    }

    private static func fieldRole(_ value: String) -> HUDMetricRole {
        value == "--" ? .muted : .normal
    }

    private static func modelGrowthFieldRole(for field: ModelGrowthCompactField) -> HUDMetricRole {
        let status = field.left.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard status != "--" else { return .muted }

        switch field.id {
        case "workload":
            switch status {
            case "DEE", "LGT", "OBS":
                return .normal
            case "UNK":
                return .muted
            default:
                return fieldRole(field.left)
            }
        default:
            return fieldRole(field.left)
        }
    }
}

struct HUDMetric: Identifiable, Equatable {
    var id: String
    var label: String
    var value: String
    var role: HUDMetricRole
}

enum HUDMetricRole: Equatable {
    case neutral
    case normal
    case muted
    case warning
    case critical
}

struct HUDSignalGroup: Equatable {
    var source: String
    var lanes: [HUDLane]
    var indicators: [HUDIndicatorSlot]
    var isEnabled: Bool = true
}

struct HUDLane: Identifiable, Equatable {
    var id: NotchCapsuleLaneID
    var source: String
    var leftWing: [HUDMetric]
    var notchVoid: [HUDMetric] = []
    var rightWing: [HUDMetric]
    var severity: HUDMetricRole
    var isEnabled: Bool = true
}

struct HUDIndicatorSlot: Identifiable, Equatable {
    var side: HUDIndicatorSide
    var source: String
    var indicator: HUDIndicator

    var id: HUDIndicatorSide { side }
}

enum HUDIndicatorSide: Hashable, Equatable {
    case left
    case right
}

struct HUDIndicator: Equatable {
    var color: HUDIndicatorColor
    var pulse: HUDIndicatorPulse = .none
    var steadyOpacity: Double? = nil
}

enum HUDIndicatorColor: Equatable {
    case green
    case yellow
    case red
    case muted
}

enum HUDIndicatorPulse: Equatable {
    case none
    case slow
    case medium
    case fast

    var cycleDuration: TimeInterval {
        switch self {
        case .none:
            return 1
        case .slow:
            return 12
        case .medium:
            return 6
        case .fast:
            return 2
        }
    }
}
