import Foundation
import XCTest
@testable import Veil

final class VPNPathSpeedProbeTests: XCTestCase {
    func testDisabledProbeUsesPassiveTunnelSpeedWithoutHTTP() {
        let loader = RecordingHTTPDataLoader()
        let probe = VPNPathSpeedProbe(
            configuration: .disabled,
            loader: loader
        )

        let speed = probe.sample(
            passiveDownloadMbps: 12.4,
            relayIdentifier: "de-fra-wg-001",
            at: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(speed.downloadMbps, 12.4)
        XCTAssertEqual(speed.source, .passiveTunnel)
        XCTAssertEqual(speed.quality, .normal)
        XCTAssertTrue(loader.recordedRequests().isEmpty)
    }

    func testDisabledProbeTreatsTinyPassiveTunnelTrafficAsIdle() {
        let loader = RecordingHTTPDataLoader()
        let probe = VPNPathSpeedProbe(
            configuration: .disabled,
            loader: loader
        )

        let speed = probe.sample(
            passiveDownloadMbps: 0.04,
            relayIdentifier: "de-fra-wg-001",
            at: Date(timeIntervalSince1970: 0)
        )

        XCTAssertNil(speed.downloadMbps)
        XCTAssertEqual(speed.quality, .idle)
        XCTAssertEqual(speed.source, .none)
        XCTAssertTrue(loader.recordedRequests().isEmpty)
    }

    func testDisabledProbeTreatsLowPassiveDemandAsNormalObservedTraffic() {
        let loader = RecordingHTTPDataLoader()
        let probe = VPNPathSpeedProbe(
            configuration: .disabled,
            loader: loader
        )

        let speed = probe.sample(
            passiveDownloadMbps: 0.42,
            relayIdentifier: "de-fra-wg-001",
            at: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(speed.downloadMbps, 0.42)
        XCTAssertEqual(speed.quality, .normal)
        XCTAssertEqual(speed.source, .passiveTunnel)
        XCTAssertTrue(loader.recordedRequests().isEmpty)
    }

    func testInitialDelayReturnsIdleBeforeProbe() {
        let loader = RecordingHTTPDataLoader()
        let probe = VPNPathSpeedProbe(
            configuration: Self.configuration(initialDelaySeconds: 10),
            loader: loader
        )

        let speed = probe.sample(
            passiveDownloadMbps: nil,
            relayIdentifier: "de-fra-wg-001",
            at: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(speed.quality, .idle)
        XCTAssertNil(speed.downloadMbps)
        XCTAssertTrue(loader.recordedRequests().isEmpty)
    }

    func testProbeDownloadsCappedTargetAndReportsMbps() throws {
        let loader = RecordingHTTPDataLoader(responses: [
            HTTPDataLoadResult(statusCode: 204, data: Data(), duration: 0.05, errorDescription: nil),
            HTTPDataLoadResult(
                statusCode: 206,
                data: Data(repeating: 1, count: VPNSpeedProbeConfiguration.defaultMaxDownloadBytes),
                duration: 0.25,
                errorDescription: nil
            )
        ])
        let probe = VPNPathSpeedProbe(
            configuration: Self.configuration(initialDelaySeconds: 0),
            loader: loader
        )

        let measuredAt = Date(timeIntervalSince1970: 10)
        let speed = probe.sample(
            passiveDownloadMbps: nil,
            relayIdentifier: "de-fra-wg-001",
            at: measuredAt
        )
        let requests = loader.recordedRequests()

        XCTAssertEqual(speed.source, .activeProbe)
        XCTAssertEqual(speed.quality, .normal)
        XCTAssertEqual(speed.measuredAt, measuredAt)
        XCTAssertEqual(speed.downloadMbps ?? -1, 4.194304, accuracy: 0.000001)
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first?.url, VPNSpeedProbeConfiguration.defaultLatencyEndpoint)
        XCTAssertEqual(requests.last?.url, VPNSpeedProbeConfiguration.defaultDownloadEndpoint)
        XCTAssertEqual(requests.last?.value(forHTTPHeaderField: "Range"), "bytes=0-131071")
        XCTAssertEqual(requests.last?.value(forHTTPHeaderField: "Cache-Control"), "no-cache")
    }

    func testActiveProbeReportsSlowWhenMeasuredCapacityIsLow() {
        let loader = RecordingHTTPDataLoader(responses: [
            HTTPDataLoadResult(statusCode: 204, data: Data(), duration: 0.05, errorDescription: nil),
            HTTPDataLoadResult(
                statusCode: 206,
                data: Data(repeating: 1, count: VPNSpeedProbeConfiguration.defaultMaxDownloadBytes),
                duration: 1.25,
                errorDescription: nil
            )
        ])
        let probe = VPNPathSpeedProbe(
            configuration: Self.configuration(initialDelaySeconds: 0),
            loader: loader
        )

        let speed = probe.sample(
            passiveDownloadMbps: nil,
            relayIdentifier: "de-fra-wg-001",
            at: Date(timeIntervalSince1970: 10)
        )

        XCTAssertEqual(speed.source, .activeProbe)
        XCTAssertEqual(speed.quality, .slow)
    }

    func testActiveTrafficSkipsProbeAndUsesPassiveTunnelSpeed() {
        let loader = RecordingHTTPDataLoader()
        let probe = VPNPathSpeedProbe(
            configuration: Self.configuration(initialDelaySeconds: 0),
            loader: loader
        )

        let speed = probe.sample(
            passiveDownloadMbps: 12.4,
            relayIdentifier: "de-fra-wg-001",
            at: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(speed.downloadMbps, 12.4)
        XCTAssertEqual(speed.source, .passiveTunnel)
        XCTAssertTrue(loader.recordedRequests().isEmpty)
    }

    func testFailureBackoffReturnsCachedFailureWithoutImmediateRetry() {
        let loader = RecordingHTTPDataLoader(responses: [
            HTTPDataLoadResult(statusCode: nil, data: Data(), duration: 0.1, errorDescription: "offline")
        ])
        let probe = VPNPathSpeedProbe(
            configuration: Self.configuration(initialDelaySeconds: 0),
            loader: loader
        )

        let first = probe.sample(
            passiveDownloadMbps: nil,
            relayIdentifier: "de-fra-wg-001",
            at: Date(timeIntervalSince1970: 0)
        )
        let second = probe.sample(
            passiveDownloadMbps: nil,
            relayIdentifier: "de-fra-wg-001",
            at: Date(timeIntervalSince1970: 30)
        )

        XCTAssertEqual(first.quality, .failed)
        XCTAssertEqual(first.failureReason, .network)
        XCTAssertEqual(second.quality, .failed)
        XCTAssertEqual(second.failureReason, .network)
        XCTAssertEqual(loader.recordedRequests().count, 1)
    }

    func testTimeoutFailureKeepsReason() {
        let loader = RecordingHTTPDataLoader(responses: [
            HTTPDataLoadResult(
                statusCode: nil,
                data: Data(),
                duration: 5,
                errorDescription: "timeout",
                failureReason: .timeout
            )
        ])
        let probe = VPNPathSpeedProbe(
            configuration: Self.configuration(initialDelaySeconds: 0),
            loader: loader
        )

        let speed = probe.sample(
            passiveDownloadMbps: nil,
            relayIdentifier: "de-fra-wg-001",
            at: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(speed.quality, .failed)
        XCTAssertEqual(speed.failureReason, .timeout)
    }

    func testHTTPFailureKeepsReason() {
        let loader = RecordingHTTPDataLoader(responses: [
            HTTPDataLoadResult(statusCode: 204, data: Data(), duration: 0.05, errorDescription: nil),
            HTTPDataLoadResult(statusCode: 503, data: Data(), duration: 0.1, errorDescription: nil)
        ])
        let probe = VPNPathSpeedProbe(
            configuration: Self.configuration(initialDelaySeconds: 0),
            loader: loader
        )

        let speed = probe.sample(
            passiveDownloadMbps: nil,
            relayIdentifier: "de-fra-wg-001",
            at: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(speed.quality, .failed)
        XCTAssertEqual(speed.failureReason, .httpStatus)
    }

    func testRelayChangeWaitsForInitialDelayAndResetsCachedSpeed() {
        let loader = RecordingHTTPDataLoader(responses: [
            HTTPDataLoadResult(statusCode: 204, data: Data(), duration: 0.05, errorDescription: nil),
            HTTPDataLoadResult(
                statusCode: 206,
                data: Data(repeating: 1, count: VPNSpeedProbeConfiguration.defaultMaxDownloadBytes),
                duration: 0.25,
                errorDescription: nil
            )
        ])
        let probe = VPNPathSpeedProbe(
            configuration: Self.configuration(initialDelaySeconds: 10),
            loader: loader
        )

        _ = probe.sample(
            passiveDownloadMbps: nil,
            relayIdentifier: "de-fra-wg-001",
            at: Date(timeIntervalSince1970: 0)
        )
        let firstMeasuredSpeed = probe.sample(
            passiveDownloadMbps: nil,
            relayIdentifier: "de-fra-wg-001",
            at: Date(timeIntervalSince1970: 11)
        )
        let afterRelayChange = probe.sample(
            passiveDownloadMbps: nil,
            relayIdentifier: "se-mma-wg-001",
            at: Date(timeIntervalSince1970: 20)
        )

        XCTAssertEqual(firstMeasuredSpeed.source, .activeProbe)
        XCTAssertEqual(afterRelayChange.quality, .idle)
        XCTAssertNil(afterRelayChange.downloadMbps)
        XCTAssertEqual(loader.recordedRequests().count, 2)
    }

    private static func configuration(initialDelaySeconds: TimeInterval) -> VPNSpeedProbeConfiguration {
        VPNSpeedProbeConfiguration(
            isEnabled: true,
            intervalSeconds: 300,
            initialDelaySeconds: initialDelaySeconds,
            timeoutSeconds: 5,
            maxDownloadBytes: VPNSpeedProbeConfiguration.defaultMaxDownloadBytes,
            activeTrafficThresholdMbps: 1.0,
            slowThresholdMbps: 2.0
        )
    }
}

private final class RecordingHTTPDataLoader: HTTPDataLoading, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [HTTPDataLoadResult]
    private var requests: [URLRequest] = []

    init(responses: [HTTPDataLoadResult] = []) {
        self.responses = responses
    }

    func load(_ request: URLRequest, timeout: TimeInterval) -> HTTPDataLoadResult {
        lock.lock()
        requests.append(request)
        let response = responses.isEmpty
            ? HTTPDataLoadResult(statusCode: nil, data: Data(), duration: timeout, errorDescription: "missing-response")
            : responses.removeFirst()
        lock.unlock()

        return response
    }

    func recordedRequests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }
}
