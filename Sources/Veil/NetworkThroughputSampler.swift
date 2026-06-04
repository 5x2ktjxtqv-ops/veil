import Darwin
import Foundation

final class NetworkThroughputSampler: @unchecked Sendable {
    private let lock = NSLock()
    private let counterReader: @Sendable () -> [InterfaceCounters]?
    private let preferredInterfacePrefixes: [String]
    private var previousByName: [String: InterfaceCounters] = [:]

    init(
        preferredInterfacePrefixes: [String] = ["utun"],
        counterReader: @escaping @Sendable () -> [InterfaceCounters]? = NetworkThroughputSampler.readCounters
    ) {
        self.preferredInterfacePrefixes = preferredInterfacePrefixes
        self.counterReader = counterReader
    }

    func sample() -> NetworkThroughput {
        guard let currentCounters = counterReader(), !currentCounters.isEmpty else {
            resetBaseline()
            return NetworkThroughput(downloadMbps: nil, uploadMbps: nil)
        }

        let previousByName = updateBaseline(with: currentCounters)

        guard !previousByName.isEmpty else {
            return NetworkThroughput(downloadMbps: nil, uploadMbps: nil)
        }

        let samples = currentCounters
            .compactMap { throughputSample(for: $0, previousByName: previousByName) }
        let preferredSamples = samples.filter(isPreferredSample)
        let candidateSamples = preferredSamples.isEmpty ? samples : preferredSamples

        guard let selectedSample = candidateSamples.max(by: { $0.totalBytes < $1.totalBytes }) else {
            return NetworkThroughput(downloadMbps: nil, uploadMbps: nil)
        }

        return NetworkThroughput(
            downloadMbps: megabitsPerSecond(
                bytes: selectedSample.rxDelta,
                interval: selectedSample.interval
            ),
            uploadMbps: megabitsPerSecond(
                bytes: selectedSample.txDelta,
                interval: selectedSample.interval
            )
        )
    }

    private func updateBaseline(with counters: [InterfaceCounters]) -> [String: InterfaceCounters] {
        lock.lock()
        let previous = previousByName
        previousByName = Self.countersByName(counters)
        lock.unlock()
        return previous
    }

    private func resetBaseline() {
        lock.lock()
        previousByName = [:]
        lock.unlock()
    }

    private static func countersByName(_ counters: [InterfaceCounters]) -> [String: InterfaceCounters] {
        Dictionary(
            counters.map { ($0.name, $0) },
            uniquingKeysWith: { _, newest in newest }
        )
    }

    private func throughputSample(
        for current: InterfaceCounters,
        previousByName: [String: InterfaceCounters]
    ) -> InterfaceThroughputSample? {
        guard let previous = previousByName[current.name],
              current.timestamp > previous.timestamp,
              let rxDelta = delta(from: previous.rxBytes, to: current.rxBytes),
              let txDelta = delta(from: previous.txBytes, to: current.txBytes) else {
            return nil
        }

        let interval = current.timestamp.timeIntervalSince(previous.timestamp)
        guard interval > 0 else { return nil }

        return InterfaceThroughputSample(
            name: current.name,
            rxDelta: rxDelta,
            txDelta: txDelta,
            interval: interval
        )
    }

    private func isPreferredSample(_ sample: InterfaceThroughputSample) -> Bool {
        preferredInterfacePrefixes.contains { sample.name.hasPrefix($0) }
    }

    private static func readCounters() -> [InterfaceCounters]? {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return nil }
        defer { freeifaddrs(addrs) }

        var countersByName: [String: InterfaceCounters] = [:]
        let timestamp = Date()

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }

            let flags = Int32(current.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }

            guard let address = current.pointee.ifa_addr else { continue }
            guard Int32(address.pointee.sa_family) == AF_LINK else { continue }
            guard let data = current.pointee.ifa_data else { continue }

            let interfaceData = data.assumingMemoryBound(to: if_data.self).pointee
            let name = String(cString: current.pointee.ifa_name)
            countersByName[name] = InterfaceCounters(
                name: name,
                rxBytes: UInt64(interfaceData.ifi_ibytes),
                txBytes: UInt64(interfaceData.ifi_obytes),
                timestamp: timestamp
            )
        }

        return Array(countersByName.values)
    }

    private func megabitsPerSecond(bytes: UInt64, interval: TimeInterval) -> Double {
        let bits = Double(bytes) * 8.0
        return bits / interval / 1_000_000.0
    }

    private func delta(from previous: UInt64, to current: UInt64) -> UInt64? {
        guard current >= previous else { return nil }
        return current - previous
    }
}

struct InterfaceCounters: Equatable, Sendable {
    var name: String
    var rxBytes: UInt64
    var txBytes: UInt64
    var timestamp: Date
}

private struct InterfaceThroughputSample {
    var name: String
    var rxDelta: UInt64
    var txDelta: UInt64
    var interval: TimeInterval

    var totalBytes: UInt64 {
        rxDelta + txDelta
    }
}
