import Foundation

struct MullvadDiagnostics {
    private let writeLine: (String) -> Void

    init(writeLine: @escaping (String) -> Void) {
        self.writeLine = writeLine
    }

    static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> MullvadDiagnostics? {
        guard booleanValue(environment["VEIL_MULLVAD_DIAGNOSTICS"], default: false) else {
            return nil
        }

        return MullvadDiagnostics { line in
            guard let data = (line + "\n").data(using: .utf8) else { return }
            FileHandle.standardError.write(data)
        }
    }

    func recordCommand(name: String, target: String? = nil, timeout: TimeInterval) {
        emit(
            event: "command",
            fields: [
                ("name", name),
                ("target", target),
                ("timeout", format(timeout))
            ]
        )
    }

    func recordPingResult(target: String, latencyMs: Double?) {
        emit(
            event: "ping_result",
            fields: [
                ("target", target),
                ("result", latencyMs == nil ? "failed" : "ok"),
                ("latency_ms", latencyMs.map(format))
            ]
        )
    }

    func recordSample(_ status: VPNStatus) {
        emit(
            event: "sample",
            fields: [
                ("connection", status.connection.rawValue),
                ("stability", status.stability.rawValue),
                ("role", status.diagnosticRole.rawValue),
                ("warning", status.warningCause?.rawValue ?? "none"),
                ("node_health", status.nodeHealth.rawValue),
                ("error", status.errorReason?.rawValue ?? "none"),
                ("latency_ms", status.latencyMs.map(format)),
                ("flap_count", status.flapCount.map(String.init)),
                ("location", status.cityCode ?? status.countryCode)
            ]
        )
    }

    private func emit(event: String, fields: [(String, String?)]) {
        let encodedFields = fields.compactMap { key, value -> String? in
            guard let value else { return nil }
            return "\(key)=\(sanitize(value))"
        }

        writeLine((["veil_mullvad_\(event)"] + encodedFields).joined(separator: " "))
    }

    private func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "\n", with: "_")
            .replacingOccurrences(of: "\t", with: "_")
    }

    private func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.1f", value)
    }

    private static func booleanValue(_ rawValue: String?, default defaultValue: Bool) -> Bool {
        guard let rawValue else { return defaultValue }

        switch rawValue.lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return defaultValue
        }
    }
}

enum VPNDiagnosticRole: String, Equatable {
    case normal
    case muted
    case warning
    case critical
}

enum VPNWarningCause: String, Equatable {
    case approvalRequired
    case cliUnavailableOrError
    case flapping
    case latencyHigh
    case latencySevere
    case latencyProbeUnavailable
    case nodeHealthDegraded
}

extension VPNStatus {
    var diagnosticRole: VPNDiagnosticRole {
        switch stability {
        case .connectedHealthy, .connectingTransient:
            return .normal
        case .connectedDegraded, .flapping, .approvalRequired, .cliUnavailableOrError:
            return .warning
        case .disconnected:
            return .critical
        case .approvalDenied, .unknown:
            return .muted
        }
    }

    var warningCause: VPNWarningCause? {
        switch stability {
        case .approvalRequired:
            return .approvalRequired
        case .cliUnavailableOrError:
            return .cliUnavailableOrError
        case .flapping:
            return .flapping
        case .connectedDegraded:
            guard let latencyMs else {
                return .latencyProbeUnavailable
            }

            if latencyMs >= VPNLatencyHealthThresholds.unhealthyMs {
                return .latencySevere
            }

            if latencyMs >= VPNLatencyHealthThresholds.degradedMs {
                return .latencyHigh
            }

            return .nodeHealthDegraded
        case .connectedHealthy, .connectingTransient, .disconnected, .approvalDenied, .unknown:
            return nil
        }
    }
}
