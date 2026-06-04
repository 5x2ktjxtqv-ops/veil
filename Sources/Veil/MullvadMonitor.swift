import Foundation

enum VPNLatencyHealthThresholds {
    static let degradedMs: Double = 400
    static let unhealthyMs: Double = 700
}

final class MullvadMonitor: @unchecked Sendable {
    private static let latencyProbeCount = 3
    private static let latencyProbeTimeout: TimeInterval = 4.2

    private struct LatencyProbeCandidate {
        var target: String
        var redactedLabel: String
    }

    private struct LatencyProbeResult {
        var target: String
        var latencyMs: Double
    }

    private let statusPollInterval: TimeInterval
    private let latencyProbeInterval: TimeInterval
    private let processRunner: any ProcessRunning
    private let stabilityTracker: MullvadStabilityTracker
    private let diagnostics: MullvadDiagnostics?
    private let speedProbe: any VPNPathSpeedProbing

    private var cachedStatus = VPNStatus(
        connection: .unknown,
        countryCode: nil,
        cityCode: nil,
        relayName: nil,
        visibleLocation: nil,
        latencyMs: nil,
        downloadMbps: nil,
        nodeHealth: .unknown,
        errorReason: .approvalRequired,
        sampledAt: Date()
    )
    private var lastStatusPoll = Date.distantPast
    private var lastLatencyProbe = Date.distantPast
    private var cachedLatency: LatencyProbeResult?

    init(
        processRunner: any ProcessRunning = ProcessRunner(),
        stabilityTracker: MullvadStabilityTracker = MullvadStabilityTracker(),
        diagnostics: MullvadDiagnostics? = MullvadDiagnostics.fromEnvironment(),
        speedProbe: any VPNPathSpeedProbing = VPNPathSpeedProbe(configuration: .disabled),
        statusPollInterval: TimeInterval = 15.0,
        latencyProbeInterval: TimeInterval = 30.0
    ) {
        self.processRunner = processRunner
        self.stabilityTracker = stabilityTracker
        self.diagnostics = diagnostics
        self.speedProbe = speedProbe
        self.statusPollInterval = statusPollInterval
        self.latencyProbeInterval = latencyProbeInterval
    }

    func reset() {
        cachedStatus = VPNStatus.approvalRequired(downloadMbps: nil)
        lastStatusPoll = .distantPast
        lastLatencyProbe = .distantPast
        cachedLatency = nil
        speedProbe.reset()
        stabilityTracker.reset()
    }

    func sample(downloadMbps: Double?, approval: MullvadReadApproval) -> VPNStatus {
        guard approval.isApproved else {
            stabilityTracker.reset()
            return fallbackStatus(for: approval, downloadMbps: downloadMbps)
        }

        let now = Date()
        var recordsObservation = false

        if now.timeIntervalSince(lastStatusPoll) >= statusPollInterval {
            cachedStatus = readStatus()
            lastStatusPoll = now
            recordsObservation = true
            clearStaleLatencyCache(for: cachedStatus)
        }

        if cachedStatus.connection == .connected {
            let candidates = latencyProbeHosts(for: cachedStatus)
            if !candidates.isEmpty,
               cachedLatency == nil || now.timeIntervalSince(lastLatencyProbe) >= latencyProbeInterval {
                cachedLatency = probeLatency(candidates: candidates)
                lastLatencyProbe = now
            }
        } else {
            cachedLatency = nil
        }

        cachedStatus.latencyMs = cachedLatency?.latencyMs
        updatePathSpeed(passiveDownloadMbps: downloadMbps, at: now)
        cachedStatus.nodeHealth = nodeHealth(for: cachedStatus)
        cachedStatus = stabilityTracker.update(
            cachedStatus,
            recordsObservation: recordsObservation,
            at: recordsObservation ? cachedStatus.sampledAt : now
        )
        diagnostics?.recordSample(cachedStatus)
        return cachedStatus
    }

    private func updatePathSpeed(passiveDownloadMbps: Double?, at now: Date) {
        guard cachedStatus.connection == .connected else {
            speedProbe.reset()
            cachedStatus.pathSpeed = .unknown
            cachedStatus.downloadMbps = nil
            return
        }

        let pathSpeed = speedProbe.sample(
            passiveDownloadMbps: passiveDownloadMbps,
            relayIdentifier: speedProbeRelayIdentifier(for: cachedStatus),
            at: now
        )
        cachedStatus.pathSpeed = pathSpeed
        cachedStatus.downloadMbps = pathSpeed.downloadMbps
    }

    private func fallbackStatus(for approval: MullvadReadApproval, downloadMbps: Double?) -> VPNStatus {
        var status = VPNStatus.approvalRequired(downloadMbps: downloadMbps)

        if approval == .denied {
            status.errorReason = .approvalDenied
        }

        return status
    }

    private func readStatus() -> VPNStatus {
        diagnostics?.recordCommand(name: "status", timeout: 2.0)

        let result = processRunner.runResult(
            "/usr/bin/env",
            arguments: ["mullvad", "status"],
            timeout: 2.0
        )

        if result.termination == .timedOut {
            return VPNStatus(
                connection: .error,
                countryCode: nil,
                cityCode: nil,
                relayName: nil,
                visibleLocation: nil,
                latencyMs: cachedLatency?.latencyMs,
                downloadMbps: nil,
                nodeHealth: .unknown,
                errorReason: .timeout,
                sampledAt: Date()
            )
        }

        let output = result.output
        guard !output.isEmpty else {
            return VPNStatus(
                connection: .error,
                countryCode: nil,
                cityCode: nil,
                relayName: nil,
                visibleLocation: nil,
                latencyMs: cachedLatency?.latencyMs,
                downloadMbps: nil,
                nodeHealth: .unknown,
                errorReason: .commandFailed,
                sampledAt: Date()
            )
        }

        return MullvadStatusParser.parse(output, cachedLatencyMs: cachedLatency?.latencyMs)
    }

    private func probeLatency(candidates: [LatencyProbeCandidate]) -> LatencyProbeResult? {
        for candidate in candidates {
            diagnostics?.recordCommand(name: "ping", target: candidate.redactedLabel, timeout: Self.latencyProbeTimeout)

            let result = processRunner.runResult(
                "/sbin/ping",
                arguments: ["-n", "-c", String(Self.latencyProbeCount), candidate.target],
                timeout: Self.latencyProbeTimeout
            )

            if result.termination != .timedOut,
               let latency = parseRepresentativePingMs(result.output) {
                diagnostics?.recordPingResult(target: candidate.redactedLabel, latencyMs: latency)
                return LatencyProbeResult(target: candidate.target, latencyMs: latency)
            }

            diagnostics?.recordPingResult(target: candidate.redactedLabel, latencyMs: nil)
        }

        return nil
    }

    private func clearStaleLatencyCache(for status: VPNStatus) {
        guard status.connection == .connected,
              let cachedLatency else {
            self.cachedLatency = nil
            return
        }

        let currentTargets = Set(latencyProbeHosts(for: status).map(\.target))
        if !currentTargets.contains(cachedLatency.target) {
            self.cachedLatency = nil
        }
    }

    private func speedProbeRelayIdentifier(for status: VPNStatus) -> String? {
        [
            status.relayName,
            status.visibleLocation,
            status.cityCode,
            status.countryCode
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private func latencyProbeHosts(for status: VPNStatus) -> [LatencyProbeCandidate] {
        var hosts: [LatencyProbeCandidate] = []

        if let relayName = status.relayName {
            hosts.append(
                LatencyProbeCandidate(
                    target: "\(relayName).relays.mullvad.net",
                    redactedLabel: "relay_host"
                )
            )
        }

        if let visibleIP = parseVisibleIPv4(status.visibleLocation) {
            hosts.append(
                LatencyProbeCandidate(
                    target: visibleIP,
                    redactedLabel: "visible_ipv4"
                )
            )
        }

        return hosts
    }

    private func parseVisibleIPv4(_ location: String?) -> String? {
        guard let location else { return nil }
        guard let match = location.range(
            of: #"\bIPv4:\s*([0-9]{1,3}(?:\.[0-9]{1,3}){3})"#,
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return nil
        }

        let fragment = String(location[match])
        let address = fragment
            .split(separator: ":", maxSplits: 1)
            .last
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return isValidIPv4(address) ? address : nil
    }

    private func isValidIPv4(_ address: String) -> Bool {
        let octets = address.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return false }

        return octets.allSatisfy { octet in
            guard let value = Int(octet) else { return false }
            return (0...255).contains(value)
        }
    }

    private func parseRepresentativePingMs(_ output: String) -> Double? {
        let samples = parsePacketPingTimesMs(output)
        if !samples.isEmpty {
            return median(samples)
        }

        return parseAveragePingMs(output)
    }

    private func parsePacketPingTimesMs(_ output: String) -> [Double] {
        output
            .split(separator: "\n")
            .compactMap { line -> Double? in
                guard let match = line.range(
                    of: #"time=([0-9]+(?:\.[0-9]+)?)\s*ms"#,
                    options: .regularExpression
                ) else {
                    return nil
                }

                let fragment = String(line[match])
                let value = fragment
                    .replacingOccurrences(of: "time=", with: "")
                    .replacingOccurrences(of: "ms", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                return Double(value)
            }
    }

    private func median(_ samples: [Double]) -> Double? {
        guard !samples.isEmpty else { return nil }

        let sorted = samples.sorted()
        let middle = sorted.count / 2

        if sorted.count % 2 == 1 {
            return sorted[middle]
        }

        return (sorted[middle - 1] + sorted[middle]) / 2
    }

    private func parseAveragePingMs(_ output: String) -> Double? {
        guard let line = output
            .split(separator: "\n")
            .map(String.init)
            .first(where: { $0.contains("min/avg/max") || $0.contains("round-trip") }) else {
            return nil
        }

        guard let values = line.split(separator: "=").last?.split(separator: " ").first else {
            return nil
        }

        let parts = values.split(separator: "/").map(String.init)
        guard parts.count > 1 else { return nil }
        return Double(parts[1])
    }

    private func nodeHealth(for status: VPNStatus) -> VPNNodeHealth {
        guard status.connection == .connected else { return .unknown }

        guard let latencyMs = status.latencyMs else {
            return status.relayName == nil && status.countryCode == nil ? .unknown : .normal
        }

        if latencyMs >= VPNLatencyHealthThresholds.unhealthyMs {
            return .unhealthy
        }

        if latencyMs >= VPNLatencyHealthThresholds.degradedMs {
            return .degraded
        }

        return .normal
    }
}

enum MullvadStatusParser {
    static func parse(_ output: String, cachedLatencyMs: Double? = nil, sampledAt: Date = Date()) -> VPNStatus {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOutput.isEmpty else {
            return VPNStatus(
                connection: .error,
                countryCode: nil,
                cityCode: nil,
                relayName: nil,
                visibleLocation: nil,
                latencyMs: cachedLatencyMs,
                downloadMbps: nil,
                nodeHealth: .unknown,
                errorReason: .commandFailed,
                sampledAt: sampledAt
            )
        }

        if trimmedOutput.localizedCaseInsensitiveContains("No such file")
            || trimmedOutput.localizedCaseInsensitiveContains("not found") {
            return VPNStatus(
                connection: .error,
                countryCode: nil,
                cityCode: nil,
                relayName: nil,
                visibleLocation: nil,
                latencyMs: cachedLatencyMs,
                downloadMbps: nil,
                nodeHealth: .unknown,
                errorReason: .cliUnavailable,
                sampledAt: sampledAt
            )
        }

        let lines = trimmedOutput
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespaces) }

        let state = parseConnectionState(from: lines.first)
        let conciseConnection = parseConciseConnectedLine(lines.first)
        let relay = normalizeRelayName(value(after: "Relay:", in: lines) ?? conciseConnection.relayName)
        let location = value(after: "Visible location:", in: lines) ?? conciseConnection.visibleLocation
        let relayParts = parseRelay(relay)
        let errorReason: VPNStatusErrorReason? = state == .unknown ? .parseFailed : nil

        return VPNStatus(
            connection: state,
            countryCode: relayParts.countryCode,
            cityCode: relayParts.cityCode ?? parseCity(fromVisibleLocation: location) ?? conciseConnection.cityCode,
            relayName: relay,
            visibleLocation: location,
            latencyMs: cachedLatencyMs,
            downloadMbps: nil,
            nodeHealth: .unknown,
            errorReason: errorReason,
            sampledAt: sampledAt
        )
    }

    private static func parseConnectionState(from line: String?) -> VPNConnectionState {
        let normalized = (line ?? "").lowercased()

        if normalized.hasPrefix("connected") { return .connected }
        if normalized.hasPrefix("connecting") || normalized.hasPrefix("disconnecting") { return .connecting }
        if normalized.hasPrefix("disconnected") { return .disconnected }
        if normalized.contains("error") || normalized.contains("blocked") { return .error }
        return .unknown
    }

    private static func parseConciseConnectedLine(_ line: String?) -> (
        relayName: String?,
        visibleLocation: String?,
        cityCode: String?
    ) {
        guard let line else { return (nil, nil, nil) }

        let prefix = "Connected to "
        guard line.localizedCaseInsensitiveContains(prefix),
              let prefixRange = line.range(of: prefix, options: .caseInsensitive),
              prefixRange.lowerBound == line.startIndex else {
            return (nil, nil, nil)
        }

        let remainder = String(line[prefixRange.upperBound...])
        let exitSegment = splitOnce(remainder, by: #"\s+via\s+"#).head
        let relayAndLocation = splitOnce(exitSegment, by: #"\s+in\s+"#)
        let relayName = normalizeRelayName(relayAndLocation.head)

        guard let rawLocation = relayAndLocation.tail else {
            return (relayName, nil, nil)
        }

        let locationParts = rawLocation
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .split(separator: ",", maxSplits: 1)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        guard locationParts.count == 2 else {
            let cityCode = rawLocation
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(3)
                .uppercased()

            return (relayName, nil, cityCode.isEmpty ? nil : cityCode)
        }

        let city = locationParts[0]
        let country = locationParts[1]
        let visibleLocation = "\(country), \(city)."
        let cityCode = city.prefix(3).uppercased()

        return (relayName, visibleLocation, cityCode.isEmpty ? nil : cityCode)
    }

    private static func value(after prefix: String, in lines: [String]) -> String? {
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        return line
            .dropFirst(prefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeRelayName(_ relay: String?) -> String? {
        guard let relay else { return nil }

        let trimmedRelay = relay.trimmingCharacters(in: .whitespacesAndNewlines)
        let exitRelay = splitOnce(trimmedRelay, by: #"\s+via\s+"#).head
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return exitRelay.isEmpty ? nil : exitRelay
    }

    private static func splitOnce(_ value: String, by pattern: String) -> (head: String, tail: String?) {
        guard let range = value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return (value, nil)
        }

        return (
            String(value[..<range.lowerBound]),
            String(value[range.upperBound...])
        )
    }

    private static func parseRelay(_ relay: String?) -> (countryCode: String?, cityCode: String?) {
        guard let relay else { return (nil, nil) }
        let parts = relay.split(separator: "-").map(String.init)

        let country = parts.first?.uppercased()
        let city = parts.count > 1 ? parts[1].uppercased() : nil
        return (country, city)
    }

    private static func parseCity(fromVisibleLocation location: String?) -> String? {
        guard let location else { return nil }
        let pieces = location.split(separator: ",", maxSplits: 1).map(String.init)
        guard pieces.count > 1 else { return nil }

        let citySegment = pieces[1].split(separator: ".").first.map(String.init) ?? pieces[1]
        let letters = citySegment
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(3)
            .uppercased()

        return letters.isEmpty ? nil : letters
    }
}

extension VPNStatus {
    static func approvalRequired(downloadMbps: Double?) -> VPNStatus {
        VPNStatus(
            connection: .error,
            countryCode: nil,
            cityCode: nil,
            relayName: nil,
            visibleLocation: nil,
            latencyMs: nil,
            downloadMbps: downloadMbps,
            nodeHealth: .unknown,
            errorReason: .approvalRequired,
            sampledAt: Date()
        )
    }
}
