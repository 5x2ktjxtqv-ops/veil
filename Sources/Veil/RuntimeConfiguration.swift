import Foundation

struct RuntimeConfiguration: Sendable {
    var hudClickThrough: Bool
    var bottomCornerMask: BottomCornerMaskConfiguration
    var statusSignals: StatusSignalConfiguration
    var powerKeepAlive: PowerKeepAliveConfiguration
    var taskStatusMonitor: TaskStatusMonitorConfiguration
    var modelGrowthMonitor: ModelGrowthMonitorConfiguration
    var vpnSpeedProbe: VPNSpeedProbeConfiguration
    var mullvadApproval: MullvadReadApproval
    var cpuTemperatureApproval: CPUReadApproval
    var shouldPromptForMullvadApproval: Bool
    var startupError: String?

    #if DEBUG
    var mockTelemetry: MockTelemetryConfiguration?
    #endif

    var shouldStartLiveTelemetry: Bool {
        guard statusSignals.isEnabled, startupError == nil else { return false }

        #if DEBUG
        return mockTelemetry == nil
        #else
        return true
        #endif
    }

    static func load(processInfo: ProcessInfo = .processInfo) -> RuntimeConfiguration {
        load(
            environment: processInfo.environment,
            arguments: processInfo.arguments,
            persistedMullvadApproval: MullvadReadApprovalPersistence.load()
        )
    }

    static func load(
        environment: [String: String],
        arguments rawArguments: [String],
        persistedMullvadApproval: MullvadReadApproval? = nil
    ) -> RuntimeConfiguration {
        let orderedArguments = Array(rawArguments.dropFirst())
        let arguments = Set(orderedArguments)

        let clickThrough = RuntimeConfiguration.booleanValue(
            environment["VEIL_CLICK_THROUGH"],
            default: true
        )

        let bottomCornerMaskEnabled = !arguments.contains("--no-bottom-corner-mask")
            && (
                arguments.contains("--bottom-corner-mask")
                    || RuntimeConfiguration.booleanValue(environment["VEIL_BOTTOM_CORNER_MASK"], default: true)
            )

        let bottomCornerMaskRadius = RuntimeConfiguration.doubleValue(
            environment["VEIL_BOTTOM_CORNER_RADIUS"],
            default: BottomCornerMaskConfiguration.defaultRadius
        )

        let bottomCornerMask = BottomCornerMaskConfiguration(
            isEnabled: bottomCornerMaskEnabled,
            radius: bottomCornerMaskRadius
        )

        let systemPowerKeepAliveRequested = arguments.contains("--system-power-keepalive")
            || RuntimeConfiguration.booleanValue(environment["VEIL_SYSTEM_POWER_KEEPALIVE"], default: false)
        let longRunRequested = arguments.contains("--long-run")
            || RuntimeConfiguration.booleanValue(environment["VEIL_LONG_RUN"], default: false)

        let powerKeepAliveEnabled = !arguments.contains("--no-power-keepalive")
            && (
                systemPowerKeepAliveRequested
                    || longRunRequested
                    || arguments.contains("--power-keepalive")
                    || RuntimeConfiguration.booleanValue(environment["VEIL_POWER_KEEPALIVE"], default: false)
            )

        let powerKeepAlive = PowerKeepAliveConfiguration(
            isEnabled: powerKeepAliveEnabled,
            systemPolicyMode: powerKeepAliveEnabled && systemPowerKeepAliveRequested
                ? .enabled
                : .disabled
        )

        let taskStatusFile = RuntimeConfiguration.fileURLValue(
            argumentValue(named: "--task-status-file", in: orderedArguments)
                ?? environment["VEIL_TASK_STATUS_FILE"]
        )
        let taskStatusMonitorEnabled = !arguments.contains("--no-task-status")
            && (
                taskStatusFile != nil
                    || arguments.contains("--task-status")
                    || RuntimeConfiguration.booleanValue(environment["VEIL_TASK_STATUS"], default: false)
            )
        let taskStatusPollIntervalSeconds = RuntimeConfiguration.doubleValue(
            argumentValue(named: "--task-status-poll-seconds", in: orderedArguments)
                ?? environment["VEIL_TASK_STATUS_POLL_SECONDS"],
            default: TaskStatusMonitorConfiguration.defaultPollIntervalSeconds
        )
        let taskStatusStaleAfterSeconds = RuntimeConfiguration.doubleValue(
            argumentValue(named: "--task-status-stale-seconds", in: orderedArguments)
                ?? environment["VEIL_TASK_STATUS_STALE_SECONDS"],
            default: TaskStatusMonitorConfiguration.defaultStaleAfterSeconds
        )
        let taskStatusMonitor = TaskStatusMonitorConfiguration(
            isEnabled: taskStatusMonitorEnabled,
            fileURL: taskStatusFile,
            pollIntervalSeconds: taskStatusPollIntervalSeconds,
            staleAfterSeconds: taskStatusStaleAfterSeconds
        )

        let modelGrowthMonitorEnabled = !arguments.contains("--no-model-growth-monitor")
            && (
                arguments.contains("--model-growth-monitor")
                    || RuntimeConfiguration.booleanValue(environment["VEIL_MODEL_GROWTH_MONITOR"], default: false)
            )
        let modelGrowthMonitorURL = RuntimeConfiguration.urlValue(
            argumentValue(named: "--model-growth-monitor-url", in: orderedArguments)
                ?? environment["VEIL_MODEL_GROWTH_URL"],
            default: ModelGrowthMonitorConfiguration.defaultEndpoint
        )
        let modelGrowthMonitorTimeoutSeconds = RuntimeConfiguration.doubleValue(
            environment["VEIL_MODEL_GROWTH_TIMEOUT_SECONDS"],
            default: ModelGrowthMonitorConfiguration.defaultTimeoutSeconds
        )
        let modelGrowthMonitor = ModelGrowthMonitorConfiguration(
            isEnabled: modelGrowthMonitorEnabled,
            endpoint: modelGrowthMonitorURL,
            timeoutSeconds: modelGrowthMonitorTimeoutSeconds
        )

        let vpnSpeedProbeEnabled = !arguments.contains("--no-vpn-speed-probe")
            && (
                arguments.contains("--vpn-speed-probe")
                    || RuntimeConfiguration.booleanValue(environment["VEIL_VPN_SPEED_PROBE"], default: false)
            )
        let vpnSpeedProbeDownloadURL = RuntimeConfiguration.urlValue(
            argumentValue(named: "--vpn-speed-probe-url", in: orderedArguments)
                ?? environment["VEIL_VPN_PROBE_URL"],
            default: VPNSpeedProbeConfiguration.defaultDownloadEndpoint
        )
        let vpnSpeedProbeLatencyURL = RuntimeConfiguration.urlValue(
            argumentValue(named: "--vpn-speed-probe-latency-url", in: orderedArguments)
                ?? environment["VEIL_VPN_PROBE_LATENCY_URL"],
            default: VPNSpeedProbeConfiguration.defaultLatencyEndpoint
        )
        let vpnSpeedProbeIntervalSeconds = RuntimeConfiguration.doubleValue(
            argumentValue(named: "--vpn-speed-probe-interval-seconds", in: orderedArguments)
                ?? environment["VEIL_VPN_PROBE_INTERVAL_SECONDS"],
            default: VPNSpeedProbeConfiguration.defaultIntervalSeconds
        )
        let vpnSpeedProbeInitialDelaySeconds = RuntimeConfiguration.doubleValue(
            argumentValue(named: "--vpn-speed-probe-initial-delay-seconds", in: orderedArguments)
                ?? environment["VEIL_VPN_PROBE_INITIAL_DELAY_SECONDS"],
            default: VPNSpeedProbeConfiguration.defaultInitialDelaySeconds
        )
        let vpnSpeedProbeTimeoutSeconds = RuntimeConfiguration.doubleValue(
            argumentValue(named: "--vpn-speed-probe-timeout-seconds", in: orderedArguments)
                ?? environment["VEIL_VPN_PROBE_TIMEOUT_SECONDS"],
            default: VPNSpeedProbeConfiguration.defaultTimeoutSeconds
        )
        let vpnSpeedProbeMaxDownloadBytes = RuntimeConfiguration.intValue(
            argumentValue(named: "--vpn-speed-probe-max-bytes", in: orderedArguments)
                ?? environment["VEIL_VPN_PROBE_MAX_BYTES"],
            default: VPNSpeedProbeConfiguration.defaultMaxDownloadBytes
        )
        let vpnSpeedProbe = VPNSpeedProbeConfiguration(
            isEnabled: vpnSpeedProbeEnabled,
            latencyEndpoint: vpnSpeedProbeLatencyURL,
            downloadEndpoint: vpnSpeedProbeDownloadURL,
            intervalSeconds: vpnSpeedProbeIntervalSeconds,
            initialDelaySeconds: vpnSpeedProbeInitialDelaySeconds,
            timeoutSeconds: vpnSpeedProbeTimeoutSeconds,
            maxDownloadBytes: vpnSpeedProbeMaxDownloadBytes
        )

        let explicitApproval = arguments.contains("--approve-mullvad-readonly")
            || RuntimeConfiguration.booleanValue(environment["VEIL_APPROVE_MULLVAD_READS"], default: false)

        let explicitDenial = arguments.contains("--deny-mullvad-readonly")
            || RuntimeConfiguration.booleanValue(environment["VEIL_DISABLE_MULLVAD_READS"], default: false)

        let approval: MullvadReadApproval
        if explicitDenial {
            approval = .denied
        } else if explicitApproval {
            approval = .approved
        } else if let persistedMullvadApproval {
            approval = persistedMullvadApproval
        } else {
            approval = .notRequested
        }

        let explicitCPUTemperatureApproval = arguments.contains("--approve-cpu-temperature-readonly")
            || RuntimeConfiguration.booleanValue(environment["VEIL_APPROVE_CPU_TEMPERATURE_READS"], default: false)

        let explicitCPUTemperatureDenial = arguments.contains("--deny-cpu-temperature-readonly")
            || RuntimeConfiguration.booleanValue(environment["VEIL_DISABLE_CPU_TEMPERATURE_READS"], default: false)

        let cpuTemperatureApproval: CPUReadApproval
        if explicitCPUTemperatureDenial {
            cpuTemperatureApproval = .denied
        } else if explicitCPUTemperatureApproval {
            cpuTemperatureApproval = .approved
        } else {
            cpuTemperatureApproval = .notRequested
        }

        let prompt = !arguments.contains("--no-mullvad-approval-prompt")
            && (
                arguments.contains("--prompt-mullvad-approval")
                    || RuntimeConfiguration.booleanValue(environment["VEIL_PROMPT_MULLVAD_APPROVAL"], default: false)
            )
        let statusSignalsForcedOff = arguments.contains("--no-status-signals")
        let explicitStatusSignals = arguments.contains("--status-signals")
            || RuntimeConfiguration.booleanValue(environment["VEIL_STATUS_SIGNALS"], default: false)

        #if DEBUG
        let mockTelemetryParse = MockTelemetryConfiguration.parse(arguments: orderedArguments)
        let shouldPromptForMullvadApproval = prompt
            && !statusSignalsForcedOff
            && approval == .notRequested
            && mockTelemetryParse.configuration == nil
            && mockTelemetryParse.error == nil
        let startupError = mockTelemetryParse.error
        let mockTelemetrySignalsEnabled = mockTelemetryParse.configuration != nil
        #else
        let shouldPromptForMullvadApproval = prompt
            && !statusSignalsForcedOff
            && approval == .notRequested
        let startupError: String? = nil
        let mockTelemetrySignalsEnabled = false
        #endif

        let statusSignals = StatusSignalConfiguration(
            isEnabled: !statusSignalsForcedOff
                && (
                    explicitStatusSignals
                        || taskStatusMonitor.isEnabled
                        || modelGrowthMonitor.isEnabled
                        || vpnSpeedProbe.isEnabled
                        || approval.isApproved
                        || cpuTemperatureApproval.isApproved
                        || shouldPromptForMullvadApproval
                        || mockTelemetrySignalsEnabled
                )
        )

        var configuration = RuntimeConfiguration(
            hudClickThrough: clickThrough,
            bottomCornerMask: bottomCornerMask,
            statusSignals: statusSignals,
            powerKeepAlive: powerKeepAlive,
            taskStatusMonitor: taskStatusMonitor,
            modelGrowthMonitor: modelGrowthMonitor,
            vpnSpeedProbe: vpnSpeedProbe,
            mullvadApproval: approval,
            cpuTemperatureApproval: cpuTemperatureApproval,
            shouldPromptForMullvadApproval: shouldPromptForMullvadApproval,
            startupError: startupError
        )

        #if DEBUG
        configuration.mockTelemetry = mockTelemetryParse.configuration
        #endif

        return configuration
    }

    static func booleanValue(_ rawValue: String?, default defaultValue: Bool) -> Bool {
        guard let rawValue else { return defaultValue }

        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return defaultValue
        }
    }

    private static func doubleValue(_ rawValue: String?, default defaultValue: Double) -> Double {
        guard let rawValue,
              let value = Double(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return defaultValue
        }

        return value
    }

    private static func intValue(_ rawValue: String?, default defaultValue: Int) -> Int {
        guard let rawValue,
              let value = Int(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return defaultValue
        }

        return value
    }

    private static func urlValue(_ rawValue: String?, default defaultValue: URL) -> URL {
        guard let rawValue = trimmedValue(rawValue),
              let url = URL(string: rawValue),
              url.scheme != nil,
              url.host != nil else {
            return defaultValue
        }

        return url
    }

    private static func fileURLValue(_ rawValue: String?) -> URL? {
        guard let rawValue = trimmedValue(rawValue) else { return nil }

        if let url = URL(string: rawValue),
           url.isFileURL {
            return url
        }

        return URL(fileURLWithPath: NSString(string: rawValue).expandingTildeInPath)
    }

    private static func trimmedValue(_ rawValue: String?) -> String? {
        guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return value
    }

    private static func argumentValue(named name: String, in arguments: [String]) -> String? {
        for index in arguments.indices {
            let argument = arguments[index]

            if argument.hasPrefix("\(name)=") {
                return String(argument.dropFirst(name.count + 1))
            }

            guard argument == name else { continue }

            let nextIndex = arguments.index(after: index)
            guard nextIndex < arguments.endIndex else { return nil }

            let value = arguments[nextIndex]
            guard !value.hasPrefix("--") else { return nil }

            return value
        }

        return nil
    }
}

struct StatusSignalConfiguration: Equatable, Sendable {
    var isEnabled: Bool
}

struct PowerKeepAliveConfiguration: Equatable, Sendable {
    var isEnabled: Bool
    var systemPolicyMode: SystemPowerPolicyMode

    init(
        isEnabled: Bool,
        systemPolicyMode: SystemPowerPolicyMode = .disabled
    ) {
        self.isEnabled = isEnabled
        self.systemPolicyMode = isEnabled ? systemPolicyMode : .disabled
    }
}

struct TaskStatusMonitorConfiguration: Equatable, Sendable {
    static let defaultPollIntervalSeconds: TimeInterval = 2
    static let defaultStaleAfterSeconds: TimeInterval = 6 * 60 * 60

    var isEnabled: Bool
    var fileURL: URL
    var pollIntervalSeconds: TimeInterval
    var staleAfterSeconds: TimeInterval

    init(
        isEnabled: Bool,
        fileURL: URL? = nil,
        pollIntervalSeconds: TimeInterval = TaskStatusMonitorConfiguration.defaultPollIntervalSeconds,
        staleAfterSeconds: TimeInterval = TaskStatusMonitorConfiguration.defaultStaleAfterSeconds
    ) {
        self.isEnabled = isEnabled
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.pollIntervalSeconds = max(pollIntervalSeconds, 1)
        self.staleAfterSeconds = max(staleAfterSeconds, 30)
    }

    static func defaultFileURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".local/state/veil", isDirectory: true)
            .appendingPathComponent("task-status.json")
    }
}

struct ModelGrowthMonitorConfiguration: Equatable, Sendable {
    static let defaultEndpoint = URL(string: "http://127.0.0.1:8765/v1/model-growth/compact-status")!
    static let defaultTimeoutSeconds: TimeInterval = 2
    private static let privateStatusPath = "/v1/model-growth/status"
    private static let publicCompactStatusPath = "/v1/model-growth/compact-status"

    var isEnabled: Bool
    var endpoint: URL
    var timeoutSeconds: TimeInterval

    init(
        isEnabled: Bool,
        endpoint: URL = ModelGrowthMonitorConfiguration.defaultEndpoint,
        timeoutSeconds: TimeInterval = ModelGrowthMonitorConfiguration.defaultTimeoutSeconds
    ) {
        self.isEnabled = isEnabled
        self.endpoint = Self.publicEndpoint(from: endpoint)
        self.timeoutSeconds = max(timeoutSeconds, 0.5)
    }

    static func publicEndpoint(from endpoint: URL) -> URL {
        guard endpoint.path == privateStatusPath else { return endpoint }
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            return defaultEndpoint
        }

        components.path = publicCompactStatusPath
        return components.url ?? defaultEndpoint
    }
}

struct VPNSpeedProbeConfiguration: Equatable, Sendable {
    static let defaultLatencyEndpoint = URL(string: "https://www.gstatic.com/generate_204")!
    static let defaultDownloadEndpoint = URL(string: "https://ajax.googleapis.com/ajax/libs/jquery/3.7.1/jquery.min.js")!
    static let defaultIntervalSeconds: TimeInterval = 300
    static let defaultInitialDelaySeconds: TimeInterval = 10
    static let defaultTimeoutSeconds: TimeInterval = 5
    static let defaultMaxDownloadBytes = 128 * 1024
    static let defaultIdleTrafficThresholdMbps = 0.1
    static let defaultActiveTrafficThresholdMbps = 1.0
    static let defaultSlowThresholdMbps = 2.0
    static let maximumDownloadBytes = 512 * 1024

    static let disabled = VPNSpeedProbeConfiguration(isEnabled: false)

    var isEnabled: Bool
    var latencyEndpoint: URL
    var downloadEndpoint: URL
    var intervalSeconds: TimeInterval
    var initialDelaySeconds: TimeInterval
    var timeoutSeconds: TimeInterval
    var maxDownloadBytes: Int
    var idleTrafficThresholdMbps: Double
    var activeTrafficThresholdMbps: Double
    var slowThresholdMbps: Double

    init(
        isEnabled: Bool,
        latencyEndpoint: URL = VPNSpeedProbeConfiguration.defaultLatencyEndpoint,
        downloadEndpoint: URL = VPNSpeedProbeConfiguration.defaultDownloadEndpoint,
        intervalSeconds: TimeInterval = VPNSpeedProbeConfiguration.defaultIntervalSeconds,
        initialDelaySeconds: TimeInterval = VPNSpeedProbeConfiguration.defaultInitialDelaySeconds,
        timeoutSeconds: TimeInterval = VPNSpeedProbeConfiguration.defaultTimeoutSeconds,
        maxDownloadBytes: Int = VPNSpeedProbeConfiguration.defaultMaxDownloadBytes,
        idleTrafficThresholdMbps: Double = VPNSpeedProbeConfiguration.defaultIdleTrafficThresholdMbps,
        activeTrafficThresholdMbps: Double = VPNSpeedProbeConfiguration.defaultActiveTrafficThresholdMbps,
        slowThresholdMbps: Double = VPNSpeedProbeConfiguration.defaultSlowThresholdMbps
    ) {
        self.isEnabled = isEnabled
        self.latencyEndpoint = latencyEndpoint
        self.downloadEndpoint = downloadEndpoint
        self.intervalSeconds = max(intervalSeconds, 15)
        self.initialDelaySeconds = max(initialDelaySeconds, 0)
        self.timeoutSeconds = max(timeoutSeconds, 1)
        self.maxDownloadBytes = min(
            max(maxDownloadBytes, 16 * 1024),
            VPNSpeedProbeConfiguration.maximumDownloadBytes
        )
        self.idleTrafficThresholdMbps = max(idleTrafficThresholdMbps, 0)
        self.activeTrafficThresholdMbps = max(activeTrafficThresholdMbps, 0)
        self.slowThresholdMbps = max(slowThresholdMbps, 0)
    }
}

enum SystemPowerPolicyMode: Equatable, Sendable {
    case disabled
    case enabled
}

struct BottomCornerMaskConfiguration: Equatable, Sendable {
    static let defaultRadius = 21.2
    static let minimumRadius = 8.0
    static let maximumRadius = 64.0

    var isEnabled: Bool
    var radius: Double

    init(isEnabled: Bool, radius: Double = BottomCornerMaskConfiguration.defaultRadius) {
        self.isEnabled = isEnabled
        self.radius = min(
            max(radius, BottomCornerMaskConfiguration.minimumRadius),
            BottomCornerMaskConfiguration.maximumRadius
        )
    }
}

#if DEBUG
struct MockTelemetryConfiguration: Equatable, Sendable {
    var fixture: MockTelemetryFixture

    static func parse(arguments: [String]) -> (configuration: MockTelemetryConfiguration?, error: String?) {
        guard let fixtureName = mockTelemetryFixtureName(in: arguments) else {
            return (nil, nil)
        }

        guard let fixture = MockTelemetryFixture(rawValue: fixtureName) else {
            let validFixtures = MockTelemetryFixture.allCases
                .map(\.rawValue)
                .joined(separator: ", ")

            return (
                nil,
                "Unknown --mock-telemetry fixture '\(fixtureName)'. Valid fixtures: \(validFixtures)."
            )
        }

        return (MockTelemetryConfiguration(fixture: fixture), nil)
    }

    private static func mockTelemetryFixtureName(in arguments: [String]) -> String? {
        for index in arguments.indices {
            let argument = arguments[index]

            if argument.hasPrefix("--mock-telemetry=") {
                let fixtureName = String(argument.dropFirst("--mock-telemetry=".count))
                return fixtureName.isEmpty ? MockTelemetryFixture.defaultCompact.rawValue : fixtureName
            }

            guard argument == "--mock-telemetry" else { continue }

            let nextIndex = arguments.index(after: index)
            guard nextIndex < arguments.endIndex else {
                return MockTelemetryFixture.defaultCompact.rawValue
            }

            let candidate = arguments[nextIndex]
            guard !candidate.hasPrefix("--") else {
                return MockTelemetryFixture.defaultCompact.rawValue
            }

            return candidate
        }

        return nil
    }
}

enum MockTelemetryFixture: String, CaseIterable, Equatable, Sendable {
    case defaultCompact
    case fullExpanded
    case cpuTemperatureUnavailable
    case modelGrowthCompact
    case vpnOff
    case approvalRequired
    case memoryElevated
    case memoryHigh
    case latencyDegraded
    case networkUnknown
}
#endif

enum MullvadReadApproval: Equatable, Sendable {
    case notRequested
    case approved
    case denied

    var isApproved: Bool {
        self == .approved
    }
}

enum MullvadReadApprovalPersistence {
    private static let key = "MullvadReadApproval"

    static func load(defaults: UserDefaults = .standard) -> MullvadReadApproval? {
        guard let rawValue = defaults.string(forKey: key) else { return nil }

        switch rawValue {
        case "approved":
            return .approved
        default:
            return nil
        }
    }

    static func saveApproved(defaults: UserDefaults = .standard) {
        defaults.set("approved", forKey: key)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

enum CPUReadApproval: Equatable, Sendable {
    case notRequested
    case approved
    case denied

    var isApproved: Bool {
        self == .approved
    }
}
