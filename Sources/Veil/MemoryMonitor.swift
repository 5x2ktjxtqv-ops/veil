import Darwin
import Foundation

struct MemoryMonitor: Sendable {
    func sample() -> MemoryStatus {
        let total = totalMemoryBytes()
        let stats = vmStats()
        let pageSize = pageSizeBytes()
        let swap = swapUsedBytes()

        guard let stats, let pageSize else {
            return MemoryStatus(
                totalBytes: total,
                usedBytes: nil,
                cachedFilesBytes: nil,
                swapUsedBytes: swap,
                pressure: .unknown
            )
        }

        let internalPages = UInt64(stats.internal_page_count) * pageSize
        let externalPages = UInt64(stats.external_page_count) * pageSize
        let purgeable = UInt64(stats.purgeable_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize

        let cachedFiles = Self.cachedFilesBytes(external: externalPages, purgeable: purgeable)
        let used = Self.displayedUsedBytes(
            internalPages: internalPages,
            purgeable: purgeable,
            wired: wired,
            compressed: compressed,
            total: total
        )
        let pressure = Self.pressureLevel(
            total: total,
            available: free + cachedFiles,
            compressed: compressed,
            swap: swap
        )

        return MemoryStatus(
            totalBytes: total,
            usedBytes: used,
            cachedFilesBytes: cachedFiles,
            swapUsedBytes: swap,
            pressure: pressure
        )
    }

    static func displayedUsedBytes(
        internalPages: UInt64,
        purgeable: UInt64,
        wired: UInt64,
        compressed: UInt64,
        total: UInt64?
    ) -> UInt64 {
        let appMemory = internalPages > purgeable ? internalPages - purgeable : 0
        let calculatedUsed = appMemory + wired + compressed
        return total.map { min($0, calculatedUsed) } ?? calculatedUsed
    }

    static func cachedFilesBytes(external: UInt64, purgeable: UInt64) -> UInt64 {
        external + purgeable
    }

    static func pressureLevel(
        total: UInt64?,
        available: UInt64,
        compressed: UInt64,
        swap: UInt64?
    ) -> HealthLevel {
        guard let total, total > 0 else { return .unknown }

        let availableRatio = Double(available) / Double(total)
        let compressedRatio = Double(compressed) / Double(total)
        let oneGiB: UInt64 = 1_073_741_824
        let swapBytes = swap ?? 0
        let compressedHigh = compressedRatio >= 0.30 && availableRatio < 0.15
        let swapHigh = swapBytes >= 4 * oneGiB && availableRatio < 0.15
        let swapElevated = swapBytes >= 2 * oneGiB && availableRatio < 0.25

        if availableRatio < 0.08 || compressedHigh || swapHigh {
            return .high
        }

        if availableRatio < 0.15 || swapElevated {
            return .elevated
        }

        return .normal
    }

    private func totalMemoryBytes() -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        let result = sysctlbyname("hw.memsize", &value, &size, nil, 0)

        guard result == 0, value > 0 else { return nil }
        return value
    }

    private func vmStats() -> vm_statistics64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }
        return stats
    }

    private func pageSizeBytes() -> UInt64? {
        var pageSize: vm_size_t = 0
        let result = host_page_size(mach_host_self(), &pageSize)

        guard result == KERN_SUCCESS, pageSize > 0 else { return nil }
        return UInt64(pageSize)
    }

    private func swapUsedBytes() -> UInt64? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride
        let result = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)

        guard result == 0 else { return nil }
        return usage.xsu_used
    }

}
