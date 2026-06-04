import Darwin
import Foundation

final class CPUUsageSampler: CPUStatusProviding, @unchecked Sendable {
    private let lock = NSLock()
    private let temperatureProvider: any CPUTemperatureProviding
    private let thermalPressureProvider: any CPUThermalPressureProviding
    private var previousTicks: CPUTimeTicks?
    private var healthTracker = CPUUsageHealthTracker()

    init(
        temperatureProvider: any CPUTemperatureProviding = UnavailableCPUTemperatureProvider(),
        thermalPressureProvider: any CPUThermalPressureProviding = ProcessInfoThermalPressureProvider()
    ) {
        self.temperatureProvider = temperatureProvider
        self.thermalPressureProvider = thermalPressureProvider
        previousTicks = Self.readTicks()
    }

    func sample() -> CPUStatus {
        guard let currentTicks = Self.readTicks() else {
            return .unavailable
        }

        lock.lock()
        defer { lock.unlock() }

        guard let previousTicks else {
            self.previousTicks = currentTicks
            return CPUStatus(
                usagePercent: nil,
                temperatureCelsius: temperatureProvider.sampleTemperatureCelsius(),
                thermalPressure: thermalPressureProvider.sampleThermalPressure()
            )
        }

        self.previousTicks = currentTicks

        let usagePercent = Self.usagePercent(from: previousTicks, to: currentTicks)
        let usageHealth = healthTracker.update(usagePercent: usagePercent, at: Date())

        return CPUStatus(
            usagePercent: usagePercent,
            temperatureCelsius: temperatureProvider.sampleTemperatureCelsius(),
            thermalPressure: thermalPressureProvider.sampleThermalPressure(),
            usageHealth: usageHealth
        )
    }

    private static func readTicks() -> CPUTimeTicks? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        return CPUTimeTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    static func usagePercent(from previous: CPUTimeTicks, to current: CPUTimeTicks) -> Double? {
        guard let totalDelta = delta(from: previous.total, to: current.total),
              let idleDelta = delta(from: previous.idle, to: current.idle),
              totalDelta > 0,
              idleDelta <= totalDelta else {
            return nil
        }

        let activeDelta = totalDelta - idleDelta
        let percent = Double(activeDelta) / Double(totalDelta) * 100.0
        return min(max(percent, 0), 100)
    }

    private static func delta(from previous: UInt64, to current: UInt64) -> UInt64? {
        guard current >= previous else { return nil }
        return current - previous
    }
}

struct ProcessInfoThermalPressureProvider: CPUThermalPressureProviding {
    private let processInfo: ProcessInfo

    init(processInfo: ProcessInfo = .processInfo) {
        self.processInfo = processInfo
    }

    func sampleThermalPressure() -> CPUThermalPressure {
        Self.pressure(from: processInfo.thermalState)
    }

    static func pressure(from thermalState: ProcessInfo.ThermalState) -> CPUThermalPressure {
        switch thermalState {
        case .nominal:
            return .nominal
        case .fair:
            return .fair
        case .serious:
            return .serious
        case .critical:
            return .critical
        @unknown default:
            return .unknown
        }
    }
}

final class PowermetricsCPUTemperatureSampler: CPUTemperatureProviding, @unchecked Sendable {
    private let lock = NSLock()
    private let processRunner: any ProcessRunning
    private let minimumSampleInterval: TimeInterval
    private let timeout: TimeInterval
    private var cachedTemperatureCelsius: Double?
    private var lastSampledAt: Date?
    private var permanentlyUnavailable = false

    init(
        processRunner: any ProcessRunning = ProcessRunner(),
        minimumSampleInterval: TimeInterval = 30,
        timeout: TimeInterval = 3
    ) {
        self.processRunner = processRunner
        self.minimumSampleInterval = minimumSampleInterval
        self.timeout = timeout
    }

    func sampleTemperatureCelsius() -> Double? {
        lock.lock()
        if permanentlyUnavailable {
            lock.unlock()
            return nil
        }
        if let lastSampledAt,
           Date().timeIntervalSince(lastSampledAt) < minimumSampleInterval {
            let cached = cachedTemperatureCelsius
            lock.unlock()
            return cached
        }
        lastSampledAt = Date()
        lock.unlock()

        let result = processRunner.runResult(
            "/usr/bin/powermetrics",
            arguments: ["--samplers", "smc", "-n", "1", "-i", "1000"],
            timeout: timeout
        )
        let output = result.output
        let temperature = result.termination == .timedOut ? nil : Self.parseTemperatureCelsius(output)
        let isPermanentlyUnavailable = temperature == nil
            && result.termination != .timedOut
            && Self.outputIndicatesPermanentUnavailable(output)

        lock.lock()
        cachedTemperatureCelsius = temperature
        permanentlyUnavailable = isPermanentlyUnavailable
        lock.unlock()

        return temperature
    }

    static func parseTemperatureCelsius(_ output: String) -> Double? {
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)

        let cpuLines = lines.filter { line in
            let lowercased = line.lowercased()
            return lowercased.contains("cpu") && lowercased.contains("temperature")
        }

        let preferredLines = cpuLines.sorted { lhs, rhs in
            let lhsLowercased = lhs.lowercased()
            let rhsLowercased = rhs.lowercased()
            return lhsLowercased.contains("die") && !rhsLowercased.contains("die")
        }

        for line in preferredLines {
            if let temperature = parseCelsiusValue(in: line) {
                return temperature
            }
        }

        return nil
    }

    static func outputIndicatesPermanentUnavailable(_ output: String) -> Bool {
        let lowercased = output.lowercased()
        return lowercased.contains("unrecognized sampler")
            || lowercased.contains("must be run as root")
            || lowercased.contains("requires root")
            || lowercased.contains("permission denied")
            || lowercased.contains("operation not permitted")
            || lowercased.contains("not authorized")
    }

    private static func parseCelsiusValue(in line: String) -> Double? {
        let pattern = #"([-+]?\d+(?:\.\d+)?)\s*(?:C|c|°C|℃)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: line) else {
            return nil
        }

        let value = Double(line[valueRange])
        guard let value, value.isFinite else { return nil }
        return value
    }
}

struct CPUUsageHealthTracker {
    var warningEnterPercent: Double = 80
    var warningExitPercent: Double = 65
    var criticalEnterPercent: Double = 95
    var criticalExitPercent: Double = 85
    var sustainedDuration: TimeInterval = 15

    private var state: HealthLevel = .normal
    private var warningCandidateSince: Date?
    private var criticalCandidateSince: Date?

    init(
        warningEnterPercent: Double = 80,
        warningExitPercent: Double = 65,
        criticalEnterPercent: Double = 95,
        criticalExitPercent: Double = 85,
        sustainedDuration: TimeInterval = 15
    ) {
        self.warningEnterPercent = warningEnterPercent
        self.warningExitPercent = warningExitPercent
        self.criticalEnterPercent = criticalEnterPercent
        self.criticalExitPercent = criticalExitPercent
        self.sustainedDuration = sustainedDuration
    }

    mutating func update(usagePercent: Double?, at date: Date) -> HealthLevel {
        guard let usagePercent, usagePercent.isFinite else {
            warningCandidateSince = nil
            criticalCandidateSince = nil
            state = .unknown
            return .unknown
        }

        if state == .unknown {
            state = .normal
        }

        updateCandidates(usagePercent: usagePercent, at: date)

        switch state {
        case .high:
            if usagePercent <= warningExitPercent {
                state = .normal
            } else if usagePercent <= criticalExitPercent {
                state = .elevated
            }
        case .elevated:
            if hasSustainedCritical(at: date) {
                state = .high
            } else if usagePercent <= warningExitPercent {
                state = .normal
            }
        case .normal, .unknown:
            if hasSustainedCritical(at: date) {
                state = .high
            } else if hasSustainedWarning(at: date) {
                state = .elevated
            }
        }

        return state
    }

    private mutating func updateCandidates(usagePercent: Double, at date: Date) {
        if usagePercent >= warningEnterPercent {
            if warningCandidateSince == nil {
                warningCandidateSince = date
            }
        } else {
            warningCandidateSince = nil
        }

        if usagePercent >= criticalEnterPercent {
            if criticalCandidateSince == nil {
                criticalCandidateSince = date
            }
        } else {
            criticalCandidateSince = nil
        }
    }

    private func hasSustainedWarning(at date: Date) -> Bool {
        guard let warningCandidateSince else { return false }
        return date.timeIntervalSince(warningCandidateSince) >= sustainedDuration
    }

    private func hasSustainedCritical(at date: Date) -> Bool {
        guard let criticalCandidateSince else { return false }
        return date.timeIntervalSince(criticalCandidateSince) >= sustainedDuration
    }
}

struct CPUTimeTicks: Equatable {
    var user: UInt64
    var system: UInt64
    var idle: UInt64
    var nice: UInt64

    var total: UInt64 {
        user + system + idle + nice
    }
}
