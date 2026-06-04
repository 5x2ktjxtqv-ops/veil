import XCTest
@testable import Veil

final class StatusHUDFormatterTests: XCTestCase {
    func testFormatsPhaseOneHudMetrics() {
        let oneGiB: UInt64 = 1_073_741_824
        let snapshot = VeilSnapshot(
            memory: MemoryStatus(
                totalBytes: 32 * oneGiB,
                usedBytes: 18 * oneGiB,
                cachedFilesBytes: 4 * oneGiB,
                swapUsedBytes: UInt64(Double(oneGiB) * 2.1),
                pressure: .normal
            ),
            vpn: VPNStatus(
                connection: .connected,
                countryCode: "DE",
                cityCode: "FRA",
                relayName: "de-fra-wg-001",
                visibleLocation: "Germany, Frankfurt.",
                latencyMs: 23.4,
                downloadMbps: 312.3,
                nodeHealth: .normal,
                errorReason: nil,
                sampledAt: Date(timeIntervalSince1970: 0)
            ),
            network: NetworkThroughput(downloadMbps: nil, uploadMbps: nil),
            cpu: CPUStatus(usagePercent: 18.2, temperatureCelsius: nil, thermalPressure: .nominal),
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(StatusHUDFormatter.ram(snapshot.memory), "18G")
        XCTAssertEqual(StatusHUDFormatter.swap(snapshot.memory), "2.1G")
        XCTAssertEqual(StatusHUDFormatter.vpn(snapshot.vpn), "FRA")
        XCTAssertEqual(StatusHUDFormatter.latency(snapshot.vpn), "23ms")
        XCTAssertEqual(StatusHUDFormatter.download(snapshot), "312M")
        XCTAssertEqual(StatusHUDFormatter.cpuUsage(snapshot.cpu), "18%")
        XCTAssertEqual(StatusHUDFormatter.cpuThermalPressure(snapshot.cpu), "OK")
    }

    func testDownloadFallsBackToPassiveNetworkThroughput() {
        let oneGiB: UInt64 = 1_073_741_824
        let snapshot = VeilSnapshot(
            memory: MemoryStatus(
                totalBytes: 16 * oneGiB,
                usedBytes: 8 * oneGiB,
                cachedFilesBytes: 2 * oneGiB,
                swapUsedBytes: 0,
                pressure: .normal
            ),
            vpn: VPNStatus.approvalRequired(downloadMbps: nil),
            network: NetworkThroughput(downloadMbps: 7.6, uploadMbps: nil),
            cpu: .unavailable,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(StatusHUDFormatter.download(snapshot), "8M")
    }

    func testVPNPathSpeedFormatsProbeStates() {
        var idle = Self.vpn(connection: .connected, cityCode: "FRA")
        idle.pathSpeed = .idle(measuredAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(StatusHUDFormatter.vpnPathSpeed(idle), "IDLE")

        var timeout = Self.vpn(connection: .connected, cityCode: "FRA")
        timeout.pathSpeed = .failed(reason: .timeout, measuredAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(StatusHUDFormatter.vpnPathSpeed(timeout), "TMO")

        var network = Self.vpn(connection: .connected, cityCode: "FRA")
        network.pathSpeed = .failed(reason: .network, measuredAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(StatusHUDFormatter.vpnPathSpeed(network), "NET")

        var http = Self.vpn(connection: .connected, cityCode: "FRA")
        http.pathSpeed = .failed(reason: .httpStatus, measuredAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(StatusHUDFormatter.vpnPathSpeed(http), "HTTP")

        var slow = Self.vpn(connection: .connected, cityCode: "FRA")
        slow.pathSpeed = .measured(
            downloadMbps: 0.42,
            quality: .slow,
            source: .activeProbe,
            measuredAt: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(StatusHUDFormatter.vpnPathSpeed(slow), "420K")

        var normal = Self.vpn(connection: .connected, cityCode: "FRA")
        normal.pathSpeed = .measured(
            downloadMbps: 8.4,
            source: .activeProbe,
            measuredAt: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(StatusHUDFormatter.vpnPathSpeed(normal), "8M")
    }

    func testDownloadFormatsSubMegabitThroughputAsKilobits() {
        let snapshot = VeilSnapshot(
            memory: MemoryStatus(
                totalBytes: nil,
                usedBytes: nil,
                cachedFilesBytes: nil,
                swapUsedBytes: nil,
                pressure: .unknown
            ),
            vpn: VPNStatus.approvalRequired(downloadMbps: nil),
            network: NetworkThroughput(downloadMbps: 0.008, uploadMbps: nil),
            cpu: .unavailable,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(StatusHUDFormatter.download(snapshot), "8K")
    }

    func testZeroDownloadFormatsAsIdleThroughput() {
        let snapshot = VeilSnapshot(
            memory: MemoryStatus(
                totalBytes: nil,
                usedBytes: nil,
                cachedFilesBytes: nil,
                swapUsedBytes: nil,
                pressure: .unknown
            ),
            vpn: VPNStatus.approvalRequired(downloadMbps: nil),
            network: NetworkThroughput(downloadMbps: 0, uploadMbps: nil),
            cpu: .unavailable,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(StatusHUDFormatter.download(snapshot), "0K")
    }

    func testUnknownMemoryValuesDisplayAsUnknown() {
        let memory = MemoryStatus(
            totalBytes: nil,
            usedBytes: nil,
            cachedFilesBytes: nil,
            swapUsedBytes: nil,
            pressure: .unknown
        )

        XCTAssertEqual(StatusHUDFormatter.ram(memory), "--")
        XCTAssertEqual(StatusHUDFormatter.swap(memory), "--")
    }

    func testMemoryUsedRoundsToNearestWholeGiB() {
        let oneGiB: UInt64 = 1_073_741_824

        XCTAssertEqual(ByteFormat.gigabytes(UInt64(Double(oneGiB) * 16.49)), "16G")
        XCTAssertEqual(ByteFormat.gigabytes(UInt64(Double(oneGiB) * 16.50)), "17G")
        XCTAssertEqual(ByteFormat.gigabytes(UInt64(Double(oneGiB) * 16.98)), "17G")
    }

    func testUnknownCPUValuesDisplayAsUnknown() {
        XCTAssertEqual(StatusHUDFormatter.cpuUsage(.unavailable), "--")
        XCTAssertEqual(StatusHUDFormatter.cpuTemperature(.unavailable), "--")
        XCTAssertEqual(StatusHUDFormatter.cpuThermalPressure(.unavailable), "--")
    }

    func testFormatsVPNStabilityStates() {
        XCTAssertEqual(StatusHUDFormatter.vpn(Self.vpn(connection: .connected, cityCode: "FRA")), "FRA")
        XCTAssertEqual(StatusHUDFormatter.vpn(Self.vpn(connection: .connecting, cityCode: nil)), "...")
        XCTAssertEqual(StatusHUDFormatter.vpn(Self.vpn(connection: .disconnected, cityCode: nil)), "OFF")
        XCTAssertEqual(StatusHUDFormatter.vpn(Self.vpn(connection: .error, cityCode: nil, errorReason: .commandFailed)), "ERR")
        XCTAssertEqual(StatusHUDFormatter.vpn(Self.vpn(connection: .error, cityCode: nil, errorReason: .approvalDenied)), "--")
        XCTAssertEqual(StatusHUDFormatter.vpn(Self.vpn(connection: .connected, cityCode: "FRA", stability: .flapping, flapCount: 3)), "FLAP")
    }

    func testCPUUsageFormatsWholePercentWithUnavailableTemperature() {
        let cpu = CPUStatus(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .nominal)

        XCTAssertEqual(StatusHUDFormatter.cpuUsage(cpu), "18%")
        XCTAssertEqual(StatusHUDFormatter.cpuTemperature(cpu), "--")
        XCTAssertEqual(StatusHUDFormatter.cpuThermalPressure(cpu), "OK")
    }

    func testFormatsCPUThermalPressureStates() {
        XCTAssertEqual(StatusHUDFormatter.cpuThermalPressure(CPUStatus(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .nominal)), "OK")
        XCTAssertEqual(StatusHUDFormatter.cpuThermalPressure(CPUStatus(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .fair)), "WARM")
        XCTAssertEqual(StatusHUDFormatter.cpuThermalPressure(CPUStatus(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .serious)), "HOT")
        XCTAssertEqual(StatusHUDFormatter.cpuThermalPressure(CPUStatus(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .critical)), "CRIT")
        XCTAssertEqual(StatusHUDFormatter.cpuThermalPressure(CPUStatus(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .unknown)), "--")
    }

    private static func vpn(
        connection: VPNConnectionState,
        cityCode: String?,
        errorReason: VPNStatusErrorReason? = nil,
        stability: VPNStabilityState? = nil,
        flapCount: Int? = nil
    ) -> VPNStatus {
        VPNStatus(
            connection: connection,
            countryCode: cityCode == nil ? nil : "DE",
            cityCode: cityCode,
            relayName: cityCode == nil ? nil : "de-fra-wg-001",
            visibleLocation: cityCode == nil ? nil : "Germany, Frankfurt.",
            latencyMs: cityCode == nil ? nil : 23.4,
            downloadMbps: nil,
            nodeHealth: connection == .connected ? .normal : .unknown,
            errorReason: errorReason,
            sampledAt: Date(timeIntervalSince1970: 0),
            stability: stability,
            flapCount: flapCount
        )
    }
}
