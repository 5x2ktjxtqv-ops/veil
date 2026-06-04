import Foundation

final class TelemetryService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.veil.telemetry", qos: .utility)
    private let memoryProvider: any MemoryStatusProviding
    private let networkProvider: any NetworkThroughputProviding
    private let cpuProvider: any CPUStatusProviding
    private let vpnProvider: any VPNStatusProviding
    private let approvalLock = NSLock()
    private var mullvadApproval: MullvadReadApproval

    init(
        mullvadApproval: MullvadReadApproval = .notRequested,
        memoryProvider: any MemoryStatusProviding = MemoryMonitor(),
        networkProvider: any NetworkThroughputProviding = NetworkThroughputSampler(),
        cpuProvider: any CPUStatusProviding = CPUUsageSampler(),
        vpnProvider: any VPNStatusProviding = MullvadMonitor()
    ) {
        self.mullvadApproval = mullvadApproval
        self.memoryProvider = memoryProvider
        self.networkProvider = networkProvider
        self.cpuProvider = cpuProvider
        self.vpnProvider = vpnProvider
    }

    func setMullvadApproval(_ approval: MullvadReadApproval) {
        approvalLock.lock()
        mullvadApproval = approval
        approvalLock.unlock()

        if !approval.isApproved {
            queue.async { [vpnProvider] in
                vpnProvider.reset()
            }
        }
    }

    func refresh(completion: @escaping @MainActor @Sendable (VeilSnapshot) -> Void) {
        Task {
            let snapshot = await refreshSnapshot()
            await completion(snapshot)
        }
    }

    func refreshSnapshot() async -> VeilSnapshot {
        let approval = currentMullvadApproval()

        return await withCheckedContinuation { continuation in
            queue.async { [memoryProvider, networkProvider, cpuProvider, vpnProvider] in
                let memory = memoryProvider.sample()
                let network = networkProvider.sample()
                let cpu = cpuProvider.sample()
                let vpn = vpnProvider.sample(downloadMbps: network.downloadMbps, approval: approval)

                let snapshot = VeilSnapshot(
                    memory: memory,
                    vpn: vpn,
                    network: network,
                    cpu: cpu,
                    updatedAt: Date()
                )

                continuation.resume(returning: snapshot)
            }
        }
    }

    private func currentMullvadApproval() -> MullvadReadApproval {
        approvalLock.lock()
        defer { approvalLock.unlock() }
        return mullvadApproval
    }
}
