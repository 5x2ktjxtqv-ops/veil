import Foundation

actor ModelGrowthCompactStatusClient {
    private let configuration: ModelGrowthMonitorConfiguration

    init(configuration: ModelGrowthMonitorConfiguration) {
        self.configuration = configuration
    }

    func fetch() async -> ModelGrowthCompactStatus {
        let request = Self.request(for: configuration)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return Self.decode(data: data, response: response, receivedAt: Date())
        } catch {
            return .unavailable(updatedAt: Date(), reason: "request_failed")
        }
    }

    static func request(for configuration: ModelGrowthMonitorConfiguration) -> URLRequest {
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = configuration.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    static func decode(
        data: Data,
        response: URLResponse?,
        receivedAt: Date
    ) -> ModelGrowthCompactStatus {
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            return .unavailable(updatedAt: receivedAt, reason: "http_\(httpResponse.statusCode)")
        }

        let textStatus = decodeDisplayTextStatus(data: data, receivedAt: receivedAt)

        do {
            let payload = try JSONDecoder().decode(CompactStatusPayload.self, from: data)
            guard payload.ok != false else {
                return .unavailable(updatedAt: receivedAt, reason: "payload_not_ok")
            }

            if let monitorStatus = monitorStatus(from: payload, receivedAt: receivedAt) {
                return monitorStatus
            }

            guard let indicator = payload.indicator,
                  let fields = payload.fields else {
                return .unavailable(updatedAt: receivedAt, reason: "payload_not_ok")
            }

            let decodedFields = fields.map {
                ModelGrowthCompactField(
                    id: $0.id,
                    left: sanitizedDisplayValue($0.left),
                    right: sanitizedDisplayValue($0.right)
                )
            }
            let heartbeat = decodedFields.first(where: { $0.id == "heartbeat" })
            let heartbeatColor = color(fromHeartbeatStatus: heartbeat?.left)
            let indicatorColor = heartbeatColor == .unknown
                ? color(from: indicator.color)
                : heartbeatColor

            return ModelGrowthCompactStatus(
                indicator: ModelGrowthIndicator(
                    color: indicatorColor,
                    code: sanitizedOptionalValue(heartbeat?.left) ?? sanitizedOptionalValue(indicator.code),
                    state: sanitizedOptionalValue(heartbeat?.left) ?? sanitizedOptionalValue(indicator.state),
                    reason: sanitizedOptionalValue(heartbeat?.right) ?? sanitizedOptionalValue(indicator.reason)
                ),
                fields: decodedFields,
                pollAfterSeconds: payload.pollAfterSeconds ?? 15,
                updatedAt: receivedAt
            )
        } catch {
            return textStatus ?? .unavailable(updatedAt: receivedAt, reason: "json_invalid")
        }
    }

    private static func monitorStatus(
        from payload: CompactStatusPayload,
        receivedAt: Date
    ) -> ModelGrowthCompactStatus? {
        let displayTextFields = fields(fromDisplayText: payload.displayText)
        let fields = compactMonitorFields(
            heartbeat: payload.heartbeat,
            workload: payload.workload,
            market: payload.market,
            fallbackFields: displayTextFields
        )

        guard !fields.isEmpty else { return nil }

        let heartbeat = fields.first(where: { $0.id == "heartbeat" })
        return ModelGrowthCompactStatus(
            indicator: ModelGrowthIndicator(
                color: color(fromHeartbeatStatus: heartbeat?.left),
                code: heartbeat?.left,
                state: heartbeat?.left,
                reason: heartbeat?.right
            ),
            fields: fields,
            pollAfterSeconds: payload.pollAfterSeconds ?? 30,
            updatedAt: receivedAt
        )
    }

    private static func compactMonitorFields(
        heartbeat: CompactMonitorSlotPayload?,
        workload: CompactMonitorSlotPayload?,
        market: CompactMonitorSlotPayload?,
        fallbackFields: [ModelGrowthCompactField]?
    ) -> [ModelGrowthCompactField] {
        let slotFields = [
            compactMonitorField(id: "heartbeat", slot: heartbeat),
            compactMonitorField(id: "workload", slot: workload),
            compactMonitorField(id: "market", slot: market)
        ]
        let fallbackFieldsByID = Dictionary(
            uniqueKeysWithValues: (fallbackFields ?? []).map { ($0.id, $0) }
        )

        return ModelGrowthCompactStatus.expectedFieldIDs.compactMap { id in
            slotFields
                .compactMap { $0 }
                .first(where: { $0.id == id })
                ?? fallbackFieldsByID[id]
        }
    }

    private static func compactMonitorField(
        id: String,
        slot: CompactMonitorSlotPayload?
    ) -> ModelGrowthCompactField? {
        guard let slot,
              sanitizedOptionalValue(slot.status) != nil || sanitizedOptionalValue(slot.reason) != nil else {
            return nil
        }

        return ModelGrowthCompactField(
            id: id,
            left: sanitizedDisplayValue(slot.status),
            right: sanitizedDisplayValue(slot.reason)
        )
    }

    private static func decodeDisplayTextStatus(
        data: Data,
        receivedAt: Date
    ) -> ModelGrowthCompactStatus? {
        guard let text = String(data: data, encoding: .utf8),
              let fields = fields(fromDisplayText: text) else {
            return nil
        }

        let heartbeat = fields.first(where: { $0.id == "heartbeat" })
        return ModelGrowthCompactStatus(
            indicator: ModelGrowthIndicator(
                color: color(fromHeartbeatStatus: heartbeat?.left),
                code: heartbeat?.left,
                state: heartbeat?.left,
                reason: heartbeat?.right
            ),
            fields: fields,
            pollAfterSeconds: 30,
            updatedAt: receivedAt
        )
    }

    private static func fields(fromDisplayText rawValue: String?) -> [ModelGrowthCompactField]? {
        guard let rawValue = sanitizedOptionalValue(rawValue) else { return nil }
        let pairs = rawValue.split(whereSeparator: { $0.isWhitespace })
        guard pairs.count >= ModelGrowthCompactStatus.expectedFieldIDs.count else { return nil }

        var fields: [ModelGrowthCompactField] = []
        for (index, pair) in pairs.prefix(ModelGrowthCompactStatus.expectedFieldIDs.count).enumerated() {
            let values = pair.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            guard values.count == 2 else { return nil }

            fields.append(
                ModelGrowthCompactField(
                    id: ModelGrowthCompactStatus.expectedFieldIDs[index],
                    left: sanitizedDisplayValue(String(values[0])),
                    right: sanitizedDisplayValue(String(values[1]))
                )
            )
        }

        return fields
    }

    private static func color(fromHeartbeatStatus rawValue: String?) -> ModelGrowthIndicatorColor {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "LIV":
            return .green
        case "WRN":
            return .yellow
        case "ERR":
            return .red
        default:
            return .unknown
        }
    }

    private static func color(from rawValue: String?) -> ModelGrowthIndicatorColor {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "green":
            return .green
        case "yellow":
            return .yellow
        case "red":
            return .red
        default:
            return .unknown
        }
    }

    private static func sanitizedDisplayValue(_ rawValue: String?) -> String {
        guard let value = sanitizedOptionalValue(rawValue) else {
            return "--"
        }

        return String(value.prefix(8))
    }

    private static func sanitizedOptionalValue(_ rawValue: String?) -> String? {
        let whitespaceAndNewlines = CharacterSet.whitespacesAndNewlines
        guard let trimmed = rawValue?.trimmingCharacters(in: whitespaceAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        return trimmed
            .components(separatedBy: whitespaceAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private struct CompactStatusPayload: Decodable {
    var ok: Bool?
    var pollAfterSeconds: TimeInterval?
    var heartbeat: CompactMonitorSlotPayload?
    var workload: CompactMonitorSlotPayload?
    var market: CompactMonitorSlotPayload?
    var displayText: String?
    var indicator: CompactIndicatorPayload?
    var fields: [CompactFieldPayload]?

    enum CodingKeys: String, CodingKey {
        case ok
        case pollAfterSeconds = "poll_after_seconds"
        case pollAfterSecondsCamel = "pollAfterSeconds"
        case heartbeat
        case workload
        case market
        case displayText = "display_text"
        case displayTextCamel = "displayText"
        case indicator
        case fields
        case data
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nestedPayload = (try? container.decode(CompactStatusPayload.self, forKey: .data))
            ?? (try? container.decode(CompactStatusPayload.self, forKey: .status))

        ok = (try? container.decodeLossyBool(forKey: .ok)) ?? nestedPayload?.ok
        pollAfterSeconds = (try? container.decode(TimeInterval.self, forKey: .pollAfterSeconds))
            ?? (try? container.decode(TimeInterval.self, forKey: .pollAfterSecondsCamel))
            ?? nestedPayload?.pollAfterSeconds
        heartbeat = (try? container.decode(CompactMonitorSlotPayload.self, forKey: .heartbeat))
            ?? nestedPayload?.heartbeat
        workload = (try? container.decode(CompactMonitorSlotPayload.self, forKey: .workload))
            ?? nestedPayload?.workload
        market = (try? container.decode(CompactMonitorSlotPayload.self, forKey: .market))
            ?? nestedPayload?.market
        displayText = (try? container.decodeLossyString(forKey: .displayText))
            ?? (try? container.decodeLossyString(forKey: .displayTextCamel))
            ?? nestedPayload?.displayText
        indicator = (try? container.decode(CompactIndicatorPayload.self, forKey: .indicator))
            ?? nestedPayload?.indicator
        fields = (try? container.decode(CompactFieldsPayload.self, forKey: .fields).fields)
            ?? nestedPayload?.fields
    }
}

private struct CompactMonitorSlotPayload: Decodable {
    var status: String?
    var reason: String?

    enum CodingKeys: String, CodingKey {
        case status
        case reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try? container.decodeLossyString(forKey: .status)
        reason = try? container.decodeLossyString(forKey: .reason)
    }
}

private struct CompactIndicatorPayload: Decodable {
    var color: String?
    var code: String?
    var state: String?
    var reason: String?

    enum CodingKeys: String, CodingKey {
        case color
        case code
        case state
        case reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        color = try? container.decodeLossyString(forKey: .color)
        code = try? container.decodeLossyString(forKey: .code)
        state = try? container.decodeLossyString(forKey: .state)
        reason = try? container.decodeLossyString(forKey: .reason)
    }
}

private struct CompactFieldPayload: Decodable {
    var id: String
    var left: String?
    var right: String?

    enum CodingKeys: String, CodingKey {
        case id
        case left
        case right
    }

    init(id: String, left: String?, right: String?) {
        self.id = id
        self.left = left
        self.right = right
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            id = (try? container.decodeLossyString(forKey: .id)) ?? ""
            left = try? container.decodeLossyString(forKey: .left)
            right = try? container.decodeLossyString(forKey: .right)
            return
        }

        if var values = try? decoder.unkeyedContainer() {
            id = ""
            left = try? values.decodeLossyString()
            right = try? values.decodeLossyString()
            return
        }

        id = ""
        left = try LossyString(from: decoder).value
        right = nil
    }

    func withFallbackID(_ fallbackID: String) -> CompactFieldPayload {
        guard id.isEmpty else { return self }
        return CompactFieldPayload(id: fallbackID, left: left, right: right)
    }
}

private struct CompactFieldsPayload: Decodable {
    var fields: [CompactFieldPayload]

    init(from decoder: Decoder) throws {
        if var array = try? decoder.unkeyedContainer() {
            var decodedFields: [CompactFieldPayload] = []

            while !array.isAtEnd {
                decodedFields.append(try array.decode(CompactFieldPayload.self))
            }

            fields = decodedFields
            return
        }

        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        fields = try container.allKeys.map { key in
            if let field = try? container.decode(CompactFieldPayload.self, forKey: key) {
                return field.withFallbackID(key.stringValue)
            }

            let value = try container.decode(LossyString.self, forKey: key).value
            return CompactFieldPayload(id: key.stringValue, left: value, right: nil)
        }
    }
}

private struct LossyString: Decodable {
    var value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else if let double = try? container.decode(Double.self) {
            value = Self.displayString(from: double)
        } else if let bool = try? container.decode(Bool.self) {
            value = String(bool)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected a compact status display value."
                )
            )
        }
    }

    private static func displayString(from value: Double) -> String {
        guard value.isFinite else { return String(value) }
        guard value.rounded() == value else { return String(value) }
        return String(Int64(value))
    }
}

private struct LossyBool: Decodable {
    var value: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
            return
        }

        if let int = try? container.decode(Int.self) {
            value = int != 0
            return
        }

        if let string = try? container.decode(String.self) {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes", "y", "on":
                value = true
            case "0", "false", "no", "n", "off":
                value = false
            default:
                throw DecodingError.typeMismatch(
                    Bool.self,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected a compact status boolean."
                    )
                )
            }
            return
        }

        throw DecodingError.typeMismatch(
            Bool.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected a compact status boolean."
            )
        )
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key) throws -> String {
        try decode(LossyString.self, forKey: key).value
    }

    func decodeLossyBool(forKey key: Key) throws -> Bool {
        try decode(LossyBool.self, forKey: key).value
    }
}

private extension UnkeyedDecodingContainer {
    mutating func decodeLossyString() throws -> String {
        try decode(LossyString.self).value
    }
}
