import Foundation

#if DEBUG
enum PreviewFixtures {
    private static let oneGiB: UInt64 = 1_073_741_824
    private static let sampleDate = Date(timeIntervalSince1970: 0)
    private static let verifiedPowerKeepAlive = PowerKeepAliveSnapshot(
        mode: .systemPolicy,
        state: .verified,
        activeAssertions: PowerAssertionKind.backgroundTaskSet,
        systemPolicyStatus: nil,
        checkedAt: sampleDate
    )

    static let defaultCompact = snapshot(
        memory: memory(usedGiB: 18, swapGiB: 2.1, pressure: .normal),
        vpn: connectedVPN(latencyMs: 23, downloadMbps: 312, nodeHealth: .normal),
        cpu: cpu(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .nominal)
    )

    static let fullExpanded = defaultCompact

    static let cpuTemperatureUnavailable = snapshot(
        memory: memory(usedGiB: 18, swapGiB: 2.1, pressure: .normal),
        vpn: connectedVPN(latencyMs: 23, downloadMbps: 312, nodeHealth: .normal),
        cpu: cpu(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .unknown)
    )

    static let vpnOff = snapshot(
        memory: memory(usedGiB: 18, swapGiB: 2.1, pressure: .normal),
        vpn: vpn(
            connection: .disconnected,
            nodeHealth: .unknown
        )
    )

    static let approvalRequired = snapshot(
        memory: memory(usedGiB: 18, swapGiB: 2.1, pressure: .normal),
        vpn: vpn(
            connection: .error,
            nodeHealth: .unknown,
            errorReason: .approvalRequired
        )
    )

    static let memoryElevated = snapshot(
        memory: memory(usedGiB: 24, swapGiB: 2.1, pressure: .elevated),
        vpn: connectedVPN(latencyMs: 28, downloadMbps: 144, nodeHealth: .normal)
    )

    static let memoryHigh = snapshot(
        memory: memory(usedGiB: 29, swapGiB: 4.3, pressure: .high),
        vpn: connectedVPN(latencyMs: 31, downloadMbps: 128, nodeHealth: .normal)
    )

    static let latencyDegraded = snapshot(
        memory: memory(usedGiB: 18, swapGiB: 2.1, pressure: .normal),
        vpn: connectedVPN(latencyMs: 182, downloadMbps: 72, nodeHealth: .degraded)
    )

    static let networkUnknown = snapshot(
        memory: memory(usedGiB: 18, swapGiB: nil, pressure: .normal),
        vpn: vpn(
            connection: .unknown,
            nodeHealth: .unknown,
            errorReason: .commandFailed
        ),
        network: NetworkThroughput(downloadMbps: nil, uploadMbps: nil)
    )

    static let modelGrowthCompact = snapshot(
        memory: memory(usedGiB: 18, swapGiB: 2.1, pressure: .normal),
        vpn: connectedVPN(latencyMs: 23, downloadMbps: 312, nodeHealth: .normal),
        cpu: cpu(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .nominal),
        modelGrowth: ModelGrowthCompactStatus(
            indicator: ModelGrowthIndicator(color: .green, code: "LIV", state: "LIV", reason: "WAT"),
            fields: [
                ModelGrowthCompactField(id: "heartbeat", left: "LIV", right: "WAT"),
                ModelGrowthCompactField(id: "workload", left: "LGT", right: "USR")
            ],
            updatedAt: sampleDate
        )
    )

    private static func snapshot(
        memory: MemoryStatus,
        vpn: VPNStatus,
        network: NetworkThroughput = NetworkThroughput(downloadMbps: nil, uploadMbps: nil),
        cpu: CPUStatus = cpu(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .nominal),
        modelGrowth: ModelGrowthCompactStatus? = nil,
        powerKeepAlive: PowerKeepAliveSnapshot = verifiedPowerKeepAlive
    ) -> VeilSnapshot {
        VeilSnapshot(
            memory: memory,
            vpn: vpn,
            network: network,
            cpu: cpu,
            modelGrowth: modelGrowth,
            powerKeepAlive: powerKeepAlive,
            updatedAt: sampleDate
        )
    }

    private static func memory(
        usedGiB: Double,
        swapGiB: Double?,
        pressure: HealthLevel
    ) -> MemoryStatus {
        MemoryStatus(
            totalBytes: 32 * oneGiB,
            usedBytes: bytes(gib: usedGiB),
            cachedFilesBytes: bytes(gib: 4),
            swapUsedBytes: swapGiB.map(bytes),
            pressure: pressure
        )
    }

    private static func connectedVPN(
        latencyMs: Double?,
        downloadMbps: Double?,
        nodeHealth: VPNNodeHealth
    ) -> VPNStatus {
        vpn(
            connection: .connected,
            countryCode: "DE",
            cityCode: "FRA",
            relayName: "de-fra-wg-001",
            visibleLocation: "Germany, Frankfurt.",
            latencyMs: latencyMs,
            downloadMbps: downloadMbps,
            nodeHealth: nodeHealth
        )
    }

    private static func vpn(
        connection: VPNConnectionState,
        countryCode: String? = nil,
        cityCode: String? = nil,
        relayName: String? = nil,
        visibleLocation: String? = nil,
        latencyMs: Double? = nil,
        downloadMbps: Double? = nil,
        nodeHealth: VPNNodeHealth,
        errorReason: VPNStatusErrorReason? = nil
    ) -> VPNStatus {
        VPNStatus(
            connection: connection,
            countryCode: countryCode,
            cityCode: cityCode,
            relayName: relayName,
            visibleLocation: visibleLocation,
            latencyMs: latencyMs,
            downloadMbps: downloadMbps,
            nodeHealth: nodeHealth,
            errorReason: errorReason,
            sampledAt: sampleDate
        )
    }

    private static func cpu(
        usagePercent: Double?,
        temperatureCelsius: Double?,
        thermalPressure: CPUThermalPressure = .unknown
    ) -> CPUStatus {
        CPUStatus(
            usagePercent: usagePercent,
            temperatureCelsius: temperatureCelsius,
            thermalPressure: thermalPressure
        )
    }

    private static func bytes(gib: Double) -> UInt64 {
        UInt64((gib * Double(oneGiB)).rounded())
    }
}
#endif
