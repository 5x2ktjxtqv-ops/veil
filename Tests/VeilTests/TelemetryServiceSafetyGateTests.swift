import Foundation
import XCTest
@testable import Veil

final class TelemetryServiceSafetyGateTests: XCTestCase {
    func testRefreshWithoutApprovalBuildsFallbackSnapshotWithoutMullvadCommands() async {
        let processRunner = TelemetryRecordingProcessRunner()
        let service = TelemetryService(
            mullvadApproval: .notRequested,
            memoryProvider: StubMemoryProvider(status: Self.memory()),
            networkProvider: StubNetworkProvider(throughput: NetworkThroughput(downloadMbps: 7.6, uploadMbps: nil)),
            cpuProvider: StubCPUProvider(status: CPUStatus(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .nominal)),
            vpnProvider: MullvadMonitor(processRunner: processRunner)
        )

        let snapshot = await service.refreshSnapshot()
        let mapping = StatusHUDMapping.notchCapsuleMetrics(for: snapshot, lane: .vpn)
        let cpuMapping = StatusHUDMapping.notchCapsuleMetrics(for: snapshot, lane: .cpu)

        XCTAssertEqual(snapshot.vpn.connection, .error)
        XCTAssertEqual(snapshot.vpn.errorReason, .approvalRequired)
        XCTAssertEqual(snapshot.vpn.downloadMbps, 7.6)
        XCTAssertNil(snapshot.vpn.latencyMs)
        XCTAssertEqual(snapshot.cpu, CPUStatus(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .nominal))
        XCTAssertTrue(processRunner.recordedCalls().isEmpty)
        XCTAssertEqual(mapping.leftWing, [
            HUDMetric(id: "vpn-primary", label: "", value: "--", role: .muted)
        ])
        XCTAssertEqual(mapping.rightWing, [
            HUDMetric(id: "vpn-quality", label: "", value: "--", role: .muted)
        ])
        XCTAssertEqual(cpuMapping.leftWing, [
            HUDMetric(id: "cpu-primary", label: "", value: "18%", role: .normal)
        ])
        XCTAssertEqual(cpuMapping.rightWing, [
            HUDMetric(id: "cpu-quality", label: "", value: "OK", role: .normal)
        ])
    }

    func testDeniedRefreshBuildsFallbackSnapshotWithoutMullvadCommands() async {
        let processRunner = TelemetryRecordingProcessRunner()
        let service = TelemetryService(
            mullvadApproval: .denied,
            memoryProvider: StubMemoryProvider(status: Self.memory()),
            networkProvider: StubNetworkProvider(throughput: NetworkThroughput(downloadMbps: nil, uploadMbps: nil)),
            cpuProvider: StubCPUProvider(status: CPUStatus(usagePercent: 42, temperatureCelsius: nil, thermalPressure: .nominal)),
            vpnProvider: MullvadMonitor(processRunner: processRunner)
        )

        let snapshot = await service.refreshSnapshot()

        XCTAssertEqual(snapshot.vpn.connection, .error)
        XCTAssertEqual(snapshot.vpn.errorReason, .approvalDenied)
        XCTAssertEqual(snapshot.cpu, CPUStatus(usagePercent: 42, temperatureCelsius: nil, thermalPressure: .nominal))
        XCTAssertTrue(processRunner.recordedCalls().isEmpty)
    }

    private static func memory() -> MemoryStatus {
        let oneGiB: UInt64 = 1_073_741_824

        return MemoryStatus(
            totalBytes: 32 * oneGiB,
            usedBytes: 18 * oneGiB,
            cachedFilesBytes: 4 * oneGiB,
            swapUsedBytes: 2 * oneGiB,
            pressure: .normal
        )
    }
}

private struct StubMemoryProvider: MemoryStatusProviding {
    var status: MemoryStatus

    func sample() -> MemoryStatus {
        status
    }
}

private struct StubNetworkProvider: NetworkThroughputProviding {
    var throughput: NetworkThroughput

    func sample() -> NetworkThroughput {
        throughput
    }
}

private struct StubCPUProvider: CPUStatusProviding {
    var status: CPUStatus

    func sample() -> CPUStatus {
        status
    }
}

private final class TelemetryRecordingProcessRunner: ProcessRunning, @unchecked Sendable {
    struct Call: Equatable {
        var executable: String
        var arguments: [String]
        var timeout: TimeInterval
    }

    private let lock = NSLock()
    private var calls: [Call] = []

    func run(_ executable: String, arguments: [String], timeout: TimeInterval) -> String? {
        lock.lock()
        calls.append(Call(executable: executable, arguments: arguments, timeout: timeout))
        lock.unlock()

        return nil
    }

    func recordedCalls() -> [Call] {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
}
