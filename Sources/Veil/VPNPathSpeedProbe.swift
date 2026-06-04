import Foundation

struct HTTPDataLoadResult: Equatable, Sendable {
    var statusCode: Int?
    var data: Data
    var duration: TimeInterval
    var errorDescription: String?
    var failureReason: VPNPathSpeedFailureReason? = nil

    var isHTTPAccessible: Bool {
        pathSpeedFailureReason() == nil
    }

    func pathSpeedFailureReason() -> VPNPathSpeedFailureReason? {
        if let failureReason {
            return failureReason
        }

        if errorDescription != nil {
            return .network
        }

        guard let statusCode else { return nil }
        return (200..<400).contains(statusCode) ? nil : .httpStatus
    }
}

protocol HTTPDataLoading: Sendable {
    func load(_ request: URLRequest, timeout: TimeInterval) -> HTTPDataLoadResult
}

final class URLSessionHTTPDataLoader: HTTPDataLoading, @unchecked Sendable {
    func load(_ request: URLRequest, timeout: TimeInterval) -> HTTPDataLoadResult {
        var request = request
        request.timeoutInterval = timeout

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        let session = URLSession(configuration: configuration)
        let semaphore = DispatchSemaphore(value: 0)
        let startedAt = Date()
        let state = HTTPDataLoadState()

        let task = session.dataTask(with: request) { responseData, response, error in
            let failureReason: VPNPathSpeedFailureReason? = if let urlError = error as? URLError {
                urlError.code == .timedOut ? .timeout : .network
            } else if error != nil {
                .network
            } else {
                nil
            }

            state.finish(
                data: responseData ?? Data(),
                statusCode: (response as? HTTPURLResponse)?.statusCode,
                errorDescription: error.map { String(describing: $0) },
                failureReason: failureReason
            )
            semaphore.signal()
        }

        task.resume()
        let waitResult = semaphore.wait(timeout: .now() + timeout + 1)
        if waitResult == .timedOut {
            task.cancel()
            state.finish(
                data: Data(),
                statusCode: nil,
                errorDescription: "timeout",
                failureReason: .timeout
            )
        }

        session.invalidateAndCancel()
        let snapshot = state.snapshot()

        return HTTPDataLoadResult(
            statusCode: snapshot.statusCode,
            data: snapshot.data,
            duration: max(Date().timeIntervalSince(startedAt), 0.001),
            errorDescription: snapshot.errorDescription,
            failureReason: snapshot.failureReason
        )
    }
}

private final class HTTPDataLoadState: @unchecked Sendable {
    private let lock = NSLock()
    private var isFinished = false
    private var data = Data()
    private var statusCode: Int?
    private var errorDescription: String?
    private var failureReason: VPNPathSpeedFailureReason?

    func finish(
        data: Data,
        statusCode: Int?,
        errorDescription: String?,
        failureReason: VPNPathSpeedFailureReason?
    ) {
        lock.lock()
        defer { lock.unlock() }

        guard !isFinished else { return }
        isFinished = true
        self.data = data
        self.statusCode = statusCode
        self.errorDescription = errorDescription
        self.failureReason = failureReason
    }

    func snapshot() -> (
        data: Data,
        statusCode: Int?,
        errorDescription: String?,
        failureReason: VPNPathSpeedFailureReason?
    ) {
        lock.lock()
        defer { lock.unlock() }

        return (data, statusCode, errorDescription, failureReason)
    }
}

protocol VPNPathSpeedProbing: Sendable {
    func sample(passiveDownloadMbps: Double?, relayIdentifier: String?, at now: Date) -> VPNPathSpeed
    func reset()
}

final class VPNPathSpeedProbe: VPNPathSpeedProbing, @unchecked Sendable {
    private let configuration: VPNSpeedProbeConfiguration
    private let loader: any HTTPDataLoading
    private let lock = NSLock()

    private var currentRelayIdentifier: String?
    private var relayChangedAt: Date?
    private var lastProbeAttempt = Date.distantPast
    private var lastSample: VPNPathSpeed?
    private var failureCount = 0

    init(
        configuration: VPNSpeedProbeConfiguration,
        loader: any HTTPDataLoading = URLSessionHTTPDataLoader()
    ) {
        self.configuration = configuration
        self.loader = loader
    }

    func sample(passiveDownloadMbps: Double?, relayIdentifier: String?, at now: Date = Date()) -> VPNPathSpeed {
        lock.lock()
        defer { lock.unlock() }

        guard configuration.isEnabled else {
            return passivePathSpeed(passiveDownloadMbps, measuredAt: now)
        }

        if let passiveSpeed = validSpeed(passiveDownloadMbps),
           passiveSpeed > configuration.activeTrafficThresholdMbps {
            let speed = measuredSpeed(
                passiveSpeed,
                source: .passiveTunnel,
                measuredAt: now
            )
            lastSample = speed
            failureCount = 0
            return speed
        }

        updateRelayStateIfNeeded(relayIdentifier: relayIdentifier, now: now)

        if let relayChangedAt,
           now.timeIntervalSince(relayChangedAt) < configuration.initialDelaySeconds {
            return lastSample ?? .idle(measuredAt: now)
        }

        if lastProbeAttempt != .distantPast,
           now.timeIntervalSince(lastProbeAttempt) < nextProbeInterval() {
            return lastSample ?? .idle(measuredAt: now)
        }

        lastProbeAttempt = now
        let speed = runActiveProbe(measuredAt: now)
        lastSample = speed

        if speed.quality == .failed {
            failureCount += 1
        } else {
            failureCount = 0
        }

        return speed
    }

    func reset() {
        lock.lock()
        currentRelayIdentifier = nil
        relayChangedAt = nil
        lastProbeAttempt = .distantPast
        lastSample = nil
        failureCount = 0
        lock.unlock()
    }

    private func updateRelayStateIfNeeded(relayIdentifier: String?, now: Date) {
        let normalizedRelayIdentifier = relayIdentifier ?? "connected"
        guard currentRelayIdentifier != normalizedRelayIdentifier else { return }

        currentRelayIdentifier = normalizedRelayIdentifier
        relayChangedAt = now
        lastProbeAttempt = .distantPast
        lastSample = nil
        failureCount = 0
    }

    private func nextProbeInterval() -> TimeInterval {
        switch failureCount {
        case 0:
            return configuration.intervalSeconds
        case 1:
            return 60
        case 2:
            return 120
        default:
            return configuration.intervalSeconds
        }
    }

    private func runActiveProbe(measuredAt: Date) -> VPNPathSpeed {
        var latencyRequest = URLRequest(url: configuration.latencyEndpoint)
        latencyRequest.cachePolicy = .reloadIgnoringLocalCacheData
        latencyRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let latencyResult = loader.load(
            latencyRequest,
            timeout: configuration.timeoutSeconds
        )
        if let failureReason = latencyResult.pathSpeedFailureReason() {
            return .failed(reason: failureReason, measuredAt: measuredAt)
        }

        var downloadRequest = URLRequest(url: configuration.downloadEndpoint)
        downloadRequest.cachePolicy = .reloadIgnoringLocalCacheData
        downloadRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        downloadRequest.setValue(
            "bytes=0-\(configuration.maxDownloadBytes - 1)",
            forHTTPHeaderField: "Range"
        )

        let downloadResult = loader.load(
            downloadRequest,
            timeout: configuration.timeoutSeconds
        )
        if let failureReason = downloadResult.pathSpeedFailureReason() {
            return .failed(reason: failureReason, measuredAt: measuredAt)
        }

        guard !downloadResult.data.isEmpty,
              downloadResult.duration > 0 else {
            return .failed(reason: .httpStatus, measuredAt: measuredAt)
        }

        let byteCount = min(downloadResult.data.count, configuration.maxDownloadBytes)
        let mbps = Double(byteCount) * 8.0 / downloadResult.duration / 1_000_000.0
        return measuredSpeed(
            mbps,
            source: .activeProbe,
            measuredAt: measuredAt
        )
    }

    private func passivePathSpeed(_ downloadMbps: Double?, measuredAt: Date) -> VPNPathSpeed {
        guard let downloadMbps = validSpeed(downloadMbps) else {
            return .unknown
        }

        guard downloadMbps >= configuration.idleTrafficThresholdMbps else {
            return .idle(measuredAt: measuredAt)
        }

        return measuredSpeed(
            downloadMbps,
            source: .passiveTunnel,
            measuredAt: measuredAt
        )
    }

    private func measuredSpeed(
        _ downloadMbps: Double,
        source: VPNPathSpeedSource,
        measuredAt: Date
    ) -> VPNPathSpeed {
        let quality: VPNPathSpeedQuality
        if source == .activeProbe,
           downloadMbps > 0,
           downloadMbps < configuration.slowThresholdMbps {
            quality = .slow
        } else {
            quality = .normal
        }

        return VPNPathSpeed.measured(
            downloadMbps: downloadMbps,
            quality: quality,
            source: source,
            measuredAt: measuredAt
        )
    }

    private func validSpeed(_ downloadMbps: Double?) -> Double? {
        guard let downloadMbps,
              downloadMbps.isFinite,
              downloadMbps >= 0 else {
            return nil
        }

        return downloadMbps
    }
}
