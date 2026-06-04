import Foundation
import XCTest
@testable import Veil

final class ModelGrowthCompactStatusClientTests: XCTestCase {
    func testCompactStatusRequestDoesNotSendAuthorizationHeader() throws {
        let request = ModelGrowthCompactStatusClient.request(
            for: ModelGrowthMonitorConfiguration(
                isEnabled: true,
                endpoint: try XCTUnwrap(URL(string: "http://127.0.0.1:8765/v1/model-growth/compact-status")),
                timeoutSeconds: 2
            )
        )

        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testDecodeCompactStatusAcceptsRuntimeLiteMonitorPayload() throws {
        let json = """
        {
          "ok": true,
          "service": "private-operator-api",
          "version": "runtime-lite-monitor.v1",
          "poll_after_seconds": 30,
          "heartbeat": { "status": "LIV", "reason": "WAT", "check_interval_seconds": 30 },
          "workload": { "status": "LGT", "reason": "USR" },
          "market": { "status": "FRE", "reason": "OKA", "check_interval_seconds": 300 },
          "display_text": "LIV|WAT LGT|USR FRE|OKA"
        }
        """

        let status = ModelGrowthCompactStatusClient.decode(
            data: Data(json.utf8),
            response: try httpResponse(statusCode: 200),
            receivedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(status.indicator.color, .green)
        XCTAssertEqual(status.indicator.code, "LIV")
        XCTAssertEqual(status.indicator.reason, "WAT")
        XCTAssertEqual(status.pollAfterSeconds, 30)
        XCTAssertEqual(status.fields, [
            ModelGrowthCompactField(id: "heartbeat", left: "LIV", right: "WAT"),
            ModelGrowthCompactField(id: "workload", left: "LGT", right: "USR"),
            ModelGrowthCompactField(id: "market", left: "FRE", right: "OKA")
        ])
    }

    func testDecodeCompactStatusKeepsGreenWhenOnlyWorkloadIsLightForUserActivity() throws {
        let json = """
        {
          "ok": true,
          "heartbeat": { "status": "LIV", "reason": "OKA" },
          "workload": { "status": "LGT", "reason": "USR" },
          "market": { "status": "FRE", "reason": "OKA" }
        }
        """

        let status = ModelGrowthCompactStatusClient.decode(
            data: Data(json.utf8),
            response: try httpResponse(statusCode: 200),
            receivedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(status.indicator.color, .green)
        XCTAssertEqual(status.indicator.code, "LIV")
        XCTAssertEqual(status.indicator.reason, "OKA")
        XCTAssertEqual(status.fields, [
            ModelGrowthCompactField(id: "heartbeat", left: "LIV", right: "OKA"),
            ModelGrowthCompactField(id: "workload", left: "LGT", right: "USR"),
            ModelGrowthCompactField(id: "market", left: "FRE", right: "OKA")
        ])
    }

    func testDecodeCompactStatusAcceptsDisplayTextOnly() throws {
        let status = ModelGrowthCompactStatusClient.decode(
            data: Data("LIV|OKA DEE|OKA OLD|QOT".utf8),
            response: try httpResponse(statusCode: 200),
            receivedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(status.indicator.color, .green)
        XCTAssertEqual(status.pollAfterSeconds, 30)
        XCTAssertEqual(status.fields, [
            ModelGrowthCompactField(id: "heartbeat", left: "LIV", right: "OKA"),
            ModelGrowthCompactField(id: "workload", left: "DEE", right: "OKA"),
            ModelGrowthCompactField(id: "market", left: "OLD", right: "QOT")
        ])
    }

    func testDecodeCompactStatusAcceptsWrappedPayloadAndNonStringValues() throws {
        let json = """
        {
          "ok": "true",
          "data": {
            "pollAfterSeconds": 9,
            "heartbeat": { "status": "ERR", "reason": "STL" },
            "workload": { "status": "UNK", "reason": 7 },
            "market": { "status": "ERR", "reason": true }
          }
        }
        """

        let status = ModelGrowthCompactStatusClient.decode(
            data: Data(json.utf8),
            response: try httpResponse(statusCode: 200),
            receivedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(status.indicator.color, .red)
        XCTAssertEqual(status.indicator.code, "ERR")
        XCTAssertEqual(status.indicator.reason, "STL")
        XCTAssertEqual(status.pollAfterSeconds, 9)
        XCTAssertEqual(status.fields, [
            ModelGrowthCompactField(id: "heartbeat", left: "ERR", right: "STL"),
            ModelGrowthCompactField(id: "workload", left: "UNK", right: "7"),
            ModelGrowthCompactField(id: "market", left: "ERR", right: "true")
        ])
    }

    func testDecodeLegacyFieldPayloadKeepsOnlyExpectedFieldsInDisplayOrder() throws {
        let json = """
        {
          "ok": true,
          "poll_after_seconds": 15,
          "indicator": {
            "color": "green",
            "code": "G",
            "state": "healthy",
            "reason": "heartbeat_fresh"
          },
          "fields": [
            { "id": "market", "left": "FRE", "right": "OKA" },
            { "id": "workload", "left": "LGT", "right": "USR" },
            { "id": "extra", "left": "NO", "right": "NO" },
            { "id": "heartbeat", "left": "LIV", "right": "OKA" }
          ]
        }
        """

        let status = ModelGrowthCompactStatusClient.decode(
            data: Data(json.utf8),
            response: try httpResponse(statusCode: 200),
            receivedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(status.indicator.color, .green)
        XCTAssertEqual(status.indicator.code, "LIV")
        XCTAssertEqual(status.indicator.reason, "OKA")
        XCTAssertEqual(status.pollAfterSeconds, 15)
        XCTAssertEqual(status.fields, [
            ModelGrowthCompactField(id: "heartbeat", left: "LIV", right: "OKA"),
            ModelGrowthCompactField(id: "workload", left: "LGT", right: "USR"),
            ModelGrowthCompactField(id: "market", left: "FRE", right: "OKA")
        ])
    }

    func testDecodeLegacyFieldPayloadLetsHeartbeatOverrideIndicatorColor() throws {
        let json = """
        {
          "ok": true,
          "indicator": {
            "color": "red",
            "code": "R",
            "state": "error",
            "reason": "legacy_rule"
          },
          "fields": [
            { "id": "heartbeat", "left": "LIV", "right": "OKA" },
            { "id": "workload", "left": "LGT", "right": "USR" },
            { "id": "market", "left": "FRE", "right": "OKA" }
          ]
        }
        """

        let status = ModelGrowthCompactStatusClient.decode(
            data: Data(json.utf8),
            response: try httpResponse(statusCode: 200),
            receivedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(status.indicator.color, .green)
        XCTAssertEqual(status.indicator.code, "LIV")
        XCTAssertEqual(status.indicator.state, "LIV")
        XCTAssertEqual(status.indicator.reason, "OKA")
    }

    func testDecodeHTTPFailureFallsBackToRedHeartbeatError() throws {
        let status = ModelGrowthCompactStatusClient.decode(
            data: Data("{}".utf8),
            response: try httpResponse(statusCode: 401),
            receivedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(status.indicator.color, .red)
        XCTAssertEqual(status.fields.first, ModelGrowthCompactField(id: "heartbeat", left: "ERR", right: "NET"))
    }

    func testDecodeInvalidJSONFallsBackToRedHeartbeatError() throws {
        let status = ModelGrowthCompactStatusClient.decode(
            data: Data("not-json".utf8),
            response: try httpResponse(statusCode: 200),
            receivedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(status.indicator.color, .red)
        XCTAssertEqual(status.fields.first, ModelGrowthCompactField(id: "heartbeat", left: "ERR", right: "NET"))
    }

    private func httpResponse(statusCode: Int) throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(
            url: URL(string: "http://127.0.0.1:8765/v1/model-growth/compact-status")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        ))
    }
}
