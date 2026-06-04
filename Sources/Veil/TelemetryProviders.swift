import Foundation

protocol MemoryStatusProviding: Sendable {
    func sample() -> MemoryStatus
}

protocol NetworkThroughputProviding: Sendable {
    func sample() -> NetworkThroughput
}

protocol CPUStatusProviding: Sendable {
    func sample() -> CPUStatus
}

protocol CPUTemperatureProviding: Sendable {
    func sampleTemperatureCelsius() -> Double?
}

protocol CPUThermalPressureProviding: Sendable {
    func sampleThermalPressure() -> CPUThermalPressure
}

protocol VPNStatusProviding: Sendable {
    func sample(downloadMbps: Double?, approval: MullvadReadApproval) -> VPNStatus
    func reset()
}

struct UnavailableCPUStatusProvider: CPUStatusProviding {
    func sample() -> CPUStatus {
        .unavailable
    }
}

struct UnavailableCPUTemperatureProvider: CPUTemperatureProviding {
    func sampleTemperatureCelsius() -> Double? {
        nil
    }
}

struct UnavailableCPUThermalPressureProvider: CPUThermalPressureProviding {
    func sampleThermalPressure() -> CPUThermalPressure {
        .unknown
    }
}

extension MemoryMonitor: MemoryStatusProviding {}
extension NetworkThroughputSampler: NetworkThroughputProviding {}
extension MullvadMonitor: VPNStatusProviding {}
