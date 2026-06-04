import XCTest
@testable import Veil

final class PowermetricsCPUTemperatureSamplerTests: XCTestCase {
    func testParsesCPUDieTemperatureFromPowermetricsOutput() {
        let output = """
        **** SMC sensors ****
        GPU die temperature: 48.2 C
        CPU die temperature: 63.7 C
        """

        XCTAssertEqual(PowermetricsCPUTemperatureSampler.parseTemperatureCelsius(output), 63.7)
    }

    func testPrefersCPUDieTemperatureWhenMultipleCPUTemperaturesExist() {
        let output = """
        CPU proximity temperature: 58.1 C
        CPU die temperature: 71.4 C
        """

        XCTAssertEqual(PowermetricsCPUTemperatureSampler.parseTemperatureCelsius(output), 71.4)
    }

    func testReturnsNilWhenOutputHasNoCPUTemperature() {
        let output = """
        **** SMC sensors ****
        GPU die temperature: 48.2 C
        """

        XCTAssertNil(PowermetricsCPUTemperatureSampler.parseTemperatureCelsius(output))
    }

    func testSamplerRunsPowermetricsWithSMCSamplerAndCachesResult() {
        let runner = CPURecordingProcessRunner { _, _, _ in
            "CPU die temperature: 62.5 C"
        }
        let sampler = PowermetricsCPUTemperatureSampler(
            processRunner: runner,
            minimumSampleInterval: 30,
            timeout: 3
        )

        XCTAssertEqual(sampler.sampleTemperatureCelsius(), 62.5)
        XCTAssertEqual(sampler.sampleTemperatureCelsius(), 62.5)

        let calls = runner.recordedCalls()
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.executable, "/usr/bin/powermetrics")
        XCTAssertEqual(calls.first?.arguments, ["--samplers", "smc", "-n", "1", "-i", "1000"])
        XCTAssertEqual(calls.first?.timeout, 3)
    }

    func testSamplerStopsRetryingAfterUnsupportedSamplerOutput() {
        let runner = CPURecordingProcessRunner { _, _, _ in
            "powermetrics: unrecognized sampler: smc"
        }
        let sampler = PowermetricsCPUTemperatureSampler(
            processRunner: runner,
            minimumSampleInterval: 0,
            timeout: 3
        )

        XCTAssertNil(sampler.sampleTemperatureCelsius())
        XCTAssertNil(sampler.sampleTemperatureCelsius())

        XCTAssertEqual(runner.recordedCalls().count, 1)
    }

    func testSamplerDoesNotTreatTimeoutAsPermanentlyUnavailable() {
        let runner = CPUTimedOutProcessRunner()
        let sampler = PowermetricsCPUTemperatureSampler(
            processRunner: runner,
            minimumSampleInterval: 0,
            timeout: 3
        )

        XCTAssertNil(sampler.sampleTemperatureCelsius())
        XCTAssertNil(sampler.sampleTemperatureCelsius())

        XCTAssertEqual(runner.recordedCalls().count, 2)
    }

    func testPermanentUnavailableDetectionCoversPermissionErrors() {
        XCTAssertTrue(PowermetricsCPUTemperatureSampler.outputIndicatesPermanentUnavailable(
            "powermetrics: unrecognized sampler: smc"
        ))
        XCTAssertTrue(PowermetricsCPUTemperatureSampler.outputIndicatesPermanentUnavailable(
            "powermetrics: must be run as root"
        ))
        XCTAssertTrue(PowermetricsCPUTemperatureSampler.outputIndicatesPermanentUnavailable(
            "Operation not permitted"
        ))
        XCTAssertFalse(PowermetricsCPUTemperatureSampler.outputIndicatesPermanentUnavailable(
            "CPU die temperature: 62.5 C"
        ))
    }
}

private final class CPURecordingProcessRunner: ProcessRunning, @unchecked Sendable {
    struct Call: Equatable {
        var executable: String
        var arguments: [String]
        var timeout: TimeInterval
    }

    private let lock = NSLock()
    private var calls: [Call] = []
    private let response: @Sendable (String, [String], TimeInterval) -> String?

    init(response: @escaping @Sendable (String, [String], TimeInterval) -> String? = { _, _, _ in nil }) {
        self.response = response
    }

    func run(_ executable: String, arguments: [String], timeout: TimeInterval) -> String? {
        lock.lock()
        calls.append(Call(executable: executable, arguments: arguments, timeout: timeout))
        lock.unlock()

        return response(executable, arguments, timeout)
    }

    func recordedCalls() -> [Call] {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
}

private final class CPUTimedOutProcessRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [CPURecordingProcessRunner.Call] = []

    func run(_ executable: String, arguments: [String], timeout: TimeInterval) -> String? {
        nil
    }

    func runResult(_ executable: String, arguments: [String], timeout: TimeInterval) -> ProcessRunResult {
        lock.lock()
        calls.append(CPURecordingProcessRunner.Call(executable: executable, arguments: arguments, timeout: timeout))
        lock.unlock()

        return ProcessRunResult(
            standardOutput: "",
            standardError: "",
            termination: .timedOut
        )
    }

    func recordedCalls() -> [CPURecordingProcessRunner.Call] {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
}
