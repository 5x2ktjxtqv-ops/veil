import Foundation

struct VeilSnapshot: Equatable, Sendable {
    var memory: MemoryStatus
    var vpn: VPNStatus
    var network: NetworkThroughput
    var cpu: CPUStatus
    var taskStatus: TaskStatusSnapshot
    var modelGrowth: ModelGrowthCompactStatus?
    var powerKeepAlive: PowerKeepAliveSnapshot
    var updatedAt: Date

    init(
        memory: MemoryStatus,
        vpn: VPNStatus,
        network: NetworkThroughput,
        cpu: CPUStatus,
        taskStatus: TaskStatusSnapshot = .inactive,
        modelGrowth: ModelGrowthCompactStatus? = nil,
        powerKeepAlive: PowerKeepAliveSnapshot = .inactive,
        updatedAt: Date
    ) {
        self.memory = memory
        self.vpn = vpn
        self.network = network
        self.cpu = cpu
        self.taskStatus = taskStatus
        self.modelGrowth = modelGrowth
        self.powerKeepAlive = powerKeepAlive
        self.updatedAt = updatedAt
    }

    static let placeholder = VeilSnapshot(
        memory: MemoryStatus(
            totalBytes: nil,
            usedBytes: nil,
            cachedFilesBytes: nil,
            swapUsedBytes: nil,
            pressure: .unknown
        ),
        vpn: VPNStatus(
            connection: .unknown,
            countryCode: nil,
            cityCode: nil,
            relayName: nil,
            visibleLocation: nil,
            latencyMs: nil,
            downloadMbps: nil,
            pathSpeed: .unknown,
            nodeHealth: .unknown,
            errorReason: .approvalRequired,
            sampledAt: Date()
        ),
        network: NetworkThroughput(downloadMbps: nil, uploadMbps: nil),
        cpu: .unavailable,
        taskStatus: .inactive,
        modelGrowth: nil,
        powerKeepAlive: .inactive,
        updatedAt: Date()
    )
}

struct TaskStatusSnapshot: Equatable, Sendable {
    var state: TaskStatusState
    var label: String?
    var detail: String?
    var updatedAt: Date?

    static let inactive = TaskStatusSnapshot(
        state: .inactive,
        label: nil,
        detail: nil,
        updatedAt: nil
    )
}

enum TaskStatusState: String, Equatable, Sendable {
    case inactive
    case running
    case succeeded
    case failed
    case attention
    case stale
    case unknown
}

struct ModelGrowthCompactStatus: Equatable, Sendable {
    static let expectedFieldIDs = ["heartbeat", "workload", "market"]

    var indicator: ModelGrowthIndicator
    var fields: [ModelGrowthCompactField]
    var pollAfterSeconds: TimeInterval
    var updatedAt: Date

    init(
        indicator: ModelGrowthIndicator,
        fields: [ModelGrowthCompactField],
        pollAfterSeconds: TimeInterval = 15,
        updatedAt: Date
    ) {
        self.indicator = indicator
        self.fields = ModelGrowthCompactStatus.normalizedFields(fields)
        self.pollAfterSeconds = max(pollAfterSeconds, 1)
        self.updatedAt = updatedAt
    }

    static func unavailable(updatedAt: Date, reason: String = "unavailable") -> ModelGrowthCompactStatus {
        ModelGrowthCompactStatus(
            indicator: ModelGrowthIndicator(color: .red, code: "R", state: "error", reason: reason),
            fields: [
                ModelGrowthCompactField(id: "heartbeat", left: "ERR", right: "NET"),
                ModelGrowthCompactField(id: "workload", left: "UNK", right: "UNK"),
                ModelGrowthCompactField(id: "market", left: "ERR", right: "UNK")
            ],
            pollAfterSeconds: 15,
            updatedAt: updatedAt
        )
    }

    private static func normalizedFields(_ fields: [ModelGrowthCompactField]) -> [ModelGrowthCompactField] {
        let normalized = expectedFieldIDs.map { id in
            fields.first(where: { $0.id == id }) ?? ModelGrowthCompactField(id: id, left: "--", right: "--")
        }

        if normalized.contains(where: { $0.left != "--" || $0.right != "--" }) {
            return normalized
        }

        let fallbackFields = Array(fields.prefix(expectedFieldIDs.count))
        guard !fallbackFields.isEmpty else { return normalized }

        return expectedFieldIDs.enumerated().map { index, id in
            guard fallbackFields.indices.contains(index) else {
                return ModelGrowthCompactField(id: id, left: "--", right: "--")
            }

            let field = fallbackFields[index]
            return ModelGrowthCompactField(id: id, left: field.left, right: field.right)
        }
    }
}

struct ModelGrowthIndicator: Equatable, Sendable {
    var color: ModelGrowthIndicatorColor
    var code: String?
    var state: String?
    var reason: String?
}

enum ModelGrowthIndicatorColor: String, Equatable, Sendable {
    case green
    case yellow
    case red
    case unknown
}

struct ModelGrowthCompactField: Identifiable, Equatable, Sendable {
    var id: String
    var left: String
    var right: String
}

struct PowerKeepAliveSnapshot: Equatable, Sendable {
    var mode: PowerKeepAliveMode
    var state: PowerKeepAliveState
    var activeAssertions: [PowerAssertionKind]
    var systemPolicyStatus: SystemPowerPolicyStatus?
    var checkedAt: Date?

    static let inactive = PowerKeepAliveSnapshot(
        mode: .disabled,
        state: .inactive,
        activeAssertions: [],
        systemPolicyStatus: nil,
        checkedAt: nil
    )
}

enum PowerKeepAliveMode: Equatable, Sendable {
    case disabled
    case assertions
    case systemPolicy
}

enum PowerKeepAliveState: Equatable, Sendable {
    case inactive
    case asserted
    case verified
    case degraded
    case failed
}

struct MemoryStatus: Equatable, Sendable {
    var totalBytes: UInt64?
    var usedBytes: UInt64?
    var cachedFilesBytes: UInt64?
    var swapUsedBytes: UInt64?
    var pressure: HealthLevel
}

struct VPNStatus: Equatable, Sendable {
    var connection: VPNConnectionState
    var countryCode: String?
    var cityCode: String?
    var relayName: String?
    var visibleLocation: String?
    var latencyMs: Double?
    var downloadMbps: Double?
    var pathSpeed: VPNPathSpeed
    var nodeHealth: VPNNodeHealth
    var errorReason: VPNStatusErrorReason?
    var sampledAt: Date
    var stabilityOverride: VPNStabilityState?
    var flapCount: Int?

    var stability: VPNStabilityState {
        let base = VPNStabilityState.classify(
            connection: connection,
            nodeHealth: nodeHealth,
            errorReason: errorReason
        )

        if base.overridesMeasuredStability {
            return base
        }

        return stabilityOverride ?? base
    }

    init(
        connection: VPNConnectionState,
        countryCode: String?,
        cityCode: String?,
        relayName: String?,
        visibleLocation: String?,
        latencyMs: Double?,
        downloadMbps: Double?,
        pathSpeed: VPNPathSpeed? = nil,
        nodeHealth: VPNNodeHealth,
        errorReason: VPNStatusErrorReason?,
        sampledAt: Date,
        stability: VPNStabilityState? = nil,
        flapCount: Int? = nil
    ) {
        self.connection = connection
        self.countryCode = countryCode
        self.cityCode = cityCode
        self.relayName = relayName
        self.visibleLocation = visibleLocation
        self.latencyMs = latencyMs
        self.downloadMbps = downloadMbps
        self.pathSpeed = pathSpeed ?? VPNPathSpeed.fromLegacyDownload(downloadMbps)
        self.nodeHealth = nodeHealth
        self.errorReason = errorReason
        self.sampledAt = sampledAt
        self.stabilityOverride = stability
        self.flapCount = flapCount
    }
}

struct VPNPathSpeed: Equatable, Sendable {
    var downloadMbps: Double?
    var quality: VPNPathSpeedQuality
    var source: VPNPathSpeedSource
    var measuredAt: Date?
    var failureReason: VPNPathSpeedFailureReason?

    static let unknown = VPNPathSpeed(
        downloadMbps: nil,
        quality: .unknown,
        source: .none,
        measuredAt: nil,
        failureReason: nil
    )

    static func idle(measuredAt: Date?) -> VPNPathSpeed {
        VPNPathSpeed(
            downloadMbps: nil,
            quality: .idle,
            source: .none,
            measuredAt: measuredAt,
            failureReason: nil
        )
    }

    static func failed(
        reason: VPNPathSpeedFailureReason = .network,
        measuredAt: Date?
    ) -> VPNPathSpeed {
        VPNPathSpeed(
            downloadMbps: nil,
            quality: .failed,
            source: .activeProbe,
            measuredAt: measuredAt,
            failureReason: reason
        )
    }

    static func measured(
        downloadMbps: Double,
        quality: VPNPathSpeedQuality = .normal,
        source: VPNPathSpeedSource,
        measuredAt: Date
    ) -> VPNPathSpeed {
        VPNPathSpeed(
            downloadMbps: downloadMbps,
            quality: quality,
            source: source,
            measuredAt: measuredAt,
            failureReason: nil
        )
    }

    static func fromLegacyDownload(_ downloadMbps: Double?) -> VPNPathSpeed {
        guard let downloadMbps else { return .unknown }

        return VPNPathSpeed(
            downloadMbps: downloadMbps,
            quality: .normal,
            source: .passiveTunnel,
            measuredAt: nil,
            failureReason: nil
        )
    }
}

enum VPNPathSpeedQuality: String, Equatable, Sendable {
    case unknown
    case idle
    case normal
    case slow
    case failed
}

enum VPNPathSpeedSource: String, Equatable, Sendable {
    case none
    case passiveTunnel
    case activeProbe
}

enum VPNPathSpeedFailureReason: String, Equatable, Sendable {
    case timeout
    case network
    case httpStatus
}

struct NetworkThroughput: Equatable, Sendable {
    var downloadMbps: Double?
    var uploadMbps: Double?
}

struct CPUStatus: Equatable, Sendable {
    var usagePercent: Double?
    var temperatureCelsius: Double?
    var thermalPressure: CPUThermalPressure
    var usageHealth: HealthLevel

    init(
        usagePercent: Double?,
        temperatureCelsius: Double?,
        thermalPressure: CPUThermalPressure = .unknown,
        usageHealth: HealthLevel? = nil
    ) {
        self.usagePercent = usagePercent
        self.temperatureCelsius = temperatureCelsius
        self.thermalPressure = thermalPressure
        self.usageHealth = usageHealth ?? (usagePercent == nil ? .unknown : .normal)
    }

    static let unavailable = CPUStatus(
        usagePercent: nil,
        temperatureCelsius: nil,
        thermalPressure: .unknown,
        usageHealth: .unknown
    )
}

enum CPUThermalPressure: String, Equatable, Sendable {
    case nominal
    case fair
    case serious
    case critical
    case unknown
}

enum HealthLevel: String, Equatable, Sendable {
    case normal
    case elevated
    case high
    case unknown
}

enum VPNConnectionState: String, Equatable, Sendable {
    case connected
    case connecting
    case disconnected
    case error
    case unknown
}

enum VPNNodeHealth: String, Equatable, Sendable {
    case normal
    case degraded
    case unhealthy
    case unknown
}

enum VPNStatusErrorReason: String, Equatable, Sendable {
    case approvalRequired
    case approvalDenied
    case cliUnavailable
    case commandFailed
    case timeout
    case parseFailed
}

enum VPNStabilityState: String, Equatable, Sendable {
    case connectedHealthy
    case connectedDegraded
    case connectingTransient
    case disconnected
    case approvalRequired
    case approvalDenied
    case cliUnavailableOrError
    case flapping
    case unknown

    var overridesMeasuredStability: Bool {
        switch self {
        case .approvalRequired, .approvalDenied, .cliUnavailableOrError, .unknown:
            return true
        case .connectedHealthy, .connectedDegraded, .connectingTransient, .disconnected, .flapping:
            return false
        }
    }

    static func classify(
        connection: VPNConnectionState,
        nodeHealth: VPNNodeHealth,
        errorReason: VPNStatusErrorReason?
    ) -> VPNStabilityState {
        switch errorReason {
        case .approvalRequired:
            return .approvalRequired
        case .approvalDenied:
            return .approvalDenied
        case .cliUnavailable, .commandFailed, .timeout, .parseFailed:
            return .cliUnavailableOrError
        case nil:
            break
        }

        switch connection {
        case .connected:
            return nodeHealth == .degraded || nodeHealth == .unhealthy
                ? .connectedDegraded
                : .connectedHealthy
        case .connecting:
            return .connectingTransient
        case .disconnected:
            return .disconnected
        case .error:
            return .cliUnavailableOrError
        case .unknown:
            return .unknown
        }
    }
}

enum ByteFormat {
    private static let bytesPerGiB: UInt64 = 1_073_741_824

    static func gigabytes(_ bytes: UInt64, digits: Int = 0) -> String {
        guard bytes > 0 else { return "0G" }

        if digits == 0 {
            let quotient = bytes / bytesPerGiB
            let remainder = bytes % bytesPerGiB
            let rounded = quotient + (remainder >= bytesPerGiB / 2 ? 1 : 0)
            return "\(rounded)G"
        }

        let value = Double(bytes) / Double(bytesPerGiB)
        return String(format: "%.\(digits)fG", value)
    }
}
