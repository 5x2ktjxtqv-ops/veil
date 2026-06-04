import Foundation

actor LocalTaskStatusFileClient {
    private let configuration: TaskStatusMonitorConfiguration

    init(configuration: TaskStatusMonitorConfiguration) {
        self.configuration = configuration
    }

    func fetch(now: Date = Date()) -> TaskStatusSnapshot {
        Self.read(
            fileURL: configuration.fileURL,
            staleAfterSeconds: configuration.staleAfterSeconds,
            now: now
        )
    }

    static func read(
        fileURL: URL,
        staleAfterSeconds: TimeInterval,
        now: Date = Date()
    ) -> TaskStatusSnapshot {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            return .inactive
        }

        return decode(data: data, staleAfterSeconds: staleAfterSeconds, now: now)
    }

    static func decode(
        data: Data,
        staleAfterSeconds: TimeInterval,
        now: Date = Date()
    ) -> TaskStatusSnapshot {
        do {
            let payload = try JSONDecoder().decode(TaskStatusPayload.self, from: data)
            let state = state(from: payload.state ?? payload.status, ok: payload.ok)
            var snapshot = TaskStatusSnapshot(
                state: state,
                label: sanitizedOptionalValue(payload.label ?? payload.tool, maxLength: 16),
                detail: sanitizedOptionalValue(payload.detail ?? payload.message, maxLength: 48),
                updatedAt: payload.updatedAt
            )

            if shouldMarkStale(snapshot, staleAfterSeconds: staleAfterSeconds, now: now) {
                snapshot.state = .stale
            }

            return snapshot
        } catch {
            return TaskStatusSnapshot(
                state: .unknown,
                label: "task",
                detail: "json_invalid",
                updatedAt: now
            )
        }
    }

    static func state(from rawValue: String?, ok: Bool? = nil) -> TaskStatusState {
        guard let rawValue = sanitizedOptionalValue(rawValue, maxLength: 64)?.lowercased() else {
            guard let ok else { return .unknown }
            return ok ? .succeeded : .failed
        }

        switch rawValue {
        case "idle", "inactive", "none", "off", "empty":
            return .inactive
        case "run", "running", "started", "start", "working", "in_progress", "in-progress", "queued", "pending":
            return .running
        case "ok", "pass", "passed", "success", "succeeded", "done", "completed", "complete":
            return .succeeded
        case "fail", "failed", "failure", "error", "errored", "cancelled", "canceled":
            return .failed
        case "warn", "warning", "attention", "blocked", "needs_attention", "needs-attention":
            return .attention
        case "stale", "timeout", "timed_out", "timed-out":
            return .stale
        default:
            return .unknown
        }
    }

    private static func shouldMarkStale(
        _ snapshot: TaskStatusSnapshot,
        staleAfterSeconds: TimeInterval,
        now: Date
    ) -> Bool {
        guard snapshot.state != .inactive,
              snapshot.state != .stale,
              let updatedAt = snapshot.updatedAt else {
            return false
        }

        return now.timeIntervalSince(updatedAt) > staleAfterSeconds
    }

    private static func sanitizedOptionalValue(_ rawValue: String?, maxLength: Int) -> String? {
        let whitespaceAndNewlines = CharacterSet.whitespacesAndNewlines
        guard let trimmed = rawValue?.trimmingCharacters(in: whitespaceAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        let collapsed = trimmed
            .components(separatedBy: whitespaceAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return String(collapsed.prefix(maxLength))
    }
}

private struct TaskStatusPayload: Decodable {
    var state: String?
    var status: String?
    var ok: Bool?
    var label: String?
    var tool: String?
    var detail: String?
    var message: String?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case state
        case status
        case ok
        case label
        case tool
        case detail
        case message
        case updatedAt = "updatedAt"
        case updatedAtSnake = "updated_at"
        case timestamp
        case time
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        state = Self.decodeString(from: container, forKey: .state)
        status = Self.decodeString(from: container, forKey: .status)
        ok = try? container.decode(Bool.self, forKey: .ok)
        label = Self.decodeString(from: container, forKey: .label)
        tool = Self.decodeString(from: container, forKey: .tool)
        detail = Self.decodeString(from: container, forKey: .detail)
        message = Self.decodeString(from: container, forKey: .message)
        updatedAt = Self.decodeDate(from: container)
    }

    private static func decodeString(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> String? {
        if let value = try? container.decode(String.self, forKey: key) {
            return value
        }

        if let value = try? container.decode(Int.self, forKey: key) {
            return "\(value)"
        }

        if let value = try? container.decode(Double.self, forKey: key) {
            return "\(value)"
        }

        if let value = try? container.decode(Bool.self, forKey: key) {
            return value ? "true" : "false"
        }

        return nil
    }

    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>) -> Date? {
        for key in [CodingKeys.updatedAt, .updatedAtSnake, .timestamp, .time] {
            if let seconds = try? container.decode(Double.self, forKey: key) {
                return Date(timeIntervalSince1970: seconds)
            }

            guard let rawValue = decodeString(from: container, forKey: key) else { continue }

            if let seconds = Double(rawValue) {
                return Date(timeIntervalSince1970: seconds)
            }

            if let date = Self.iso8601Date(from: rawValue) {
                return date
            }
        }

        return nil
    }

    private static func iso8601Date(from rawValue: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: rawValue) {
            return date
        }

        return ISO8601DateFormatter().date(from: rawValue)
    }
}
