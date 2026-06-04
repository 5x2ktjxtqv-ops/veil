import XCTest
@testable import Veil

final class NetworkThroughputSamplerTests: XCTestCase {
    func testFirstSampleReturnsUnknownUntilThereIsPreviousState() {
        let sequence = InterfaceCounterSequence(samples: [
            [
                InterfaceCounters(
                    name: "en0",
                    rxBytes: 1_000,
                    txBytes: 2_000,
                    timestamp: Date(timeIntervalSince1970: 0)
                )
            ]
        ])
        let sampler = NetworkThroughputSampler(counterReader: sequence.next)

        XCTAssertEqual(
            sampler.sample(),
            NetworkThroughput(downloadMbps: nil, uploadMbps: nil)
        )
    }

    func testSampleUsesBusiestSingleInterfaceInsteadOfSummingAllInterfaces() {
        let sequence = InterfaceCounterSequence(samples: [
            [
                InterfaceCounters(
                    name: "en0",
                    rxBytes: 1_000_000,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 0)
                ),
                InterfaceCounters(
                    name: "utun4",
                    rxBytes: 2_000_000,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 0)
                )
            ],
            [
                InterfaceCounters(
                    name: "en0",
                    rxBytes: 2_000_000,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 1)
                ),
                InterfaceCounters(
                    name: "utun4",
                    rxBytes: 5_000_000,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 1)
                )
            ]
        ])
        let sampler = NetworkThroughputSampler(counterReader: sequence.next)

        _ = sampler.sample()
        let throughput = sampler.sample()

        XCTAssertEqual(throughput.downloadMbps ?? -1, 24, accuracy: 0.001)
        XCTAssertEqual(throughput.uploadMbps ?? -1, 0, accuracy: 0.001)
    }

    func testSamplePrefersTunnelInterfaceOverBusierPhysicalInterface() {
        let sequence = InterfaceCounterSequence(samples: [
            [
                InterfaceCounters(
                    name: "en0",
                    rxBytes: 1_000_000,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 0)
                ),
                InterfaceCounters(
                    name: "utun4",
                    rxBytes: 1_000_000,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 0)
                )
            ],
            [
                InterfaceCounters(
                    name: "en0",
                    rxBytes: 9_000_000,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 1)
                ),
                InterfaceCounters(
                    name: "utun4",
                    rxBytes: 2_000_000,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 1)
                )
            ]
        ])
        let sampler = NetworkThroughputSampler(counterReader: sequence.next)

        _ = sampler.sample()
        let throughput = sampler.sample()

        XCTAssertEqual(throughput.downloadMbps ?? -1, 8, accuracy: 0.001)
        XCTAssertEqual(throughput.uploadMbps ?? -1, 0, accuracy: 0.001)
    }

    func testCounterRegressionIsIgnored() {
        let sequence = InterfaceCounterSequence(samples: [
            [
                InterfaceCounters(
                    name: "en0",
                    rxBytes: 2_000_000,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 0)
                )
            ],
            [
                InterfaceCounters(
                    name: "en0",
                    rxBytes: 1_000_000,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 1)
                )
            ]
        ])
        let sampler = NetworkThroughputSampler(counterReader: sequence.next)

        _ = sampler.sample()

        XCTAssertEqual(
            sampler.sample(),
            NetworkThroughput(downloadMbps: nil, uploadMbps: nil)
        )
    }

    func testUnavailableSampleClearsBaselineBeforeNextReading() {
        let sequence = InterfaceCounterSequence(samples: [
            [
                InterfaceCounters(
                    name: "en0",
                    rxBytes: 1_000_000,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 0)
                )
            ],
            nil,
            [
                InterfaceCounters(
                    name: "en0",
                    rxBytes: 9_000_000,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 10)
                )
            ],
            [
                InterfaceCounters(
                    name: "en0",
                    rxBytes: 17_000_000,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 11)
                )
            ]
        ])
        let sampler = NetworkThroughputSampler(counterReader: sequence.next)

        _ = sampler.sample()
        XCTAssertEqual(sampler.sample(), NetworkThroughput(downloadMbps: nil, uploadMbps: nil))
        XCTAssertEqual(sampler.sample(), NetworkThroughput(downloadMbps: nil, uploadMbps: nil))

        let throughput = sampler.sample()
        XCTAssertEqual(throughput.downloadMbps ?? -1, 64, accuracy: 0.001)
        XCTAssertEqual(throughput.uploadMbps ?? -1, 0, accuracy: 0.001)
    }

    func testDuplicateInterfaceNamesKeepNewestCounter() {
        let sequence = InterfaceCounterSequence(samples: [
            [
                InterfaceCounters(
                    name: "en0",
                    rxBytes: 100,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 0)
                ),
                InterfaceCounters(
                    name: "en0",
                    rxBytes: 1_000,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 0)
                )
            ],
            [
                InterfaceCounters(
                    name: "en0",
                    rxBytes: 2_000,
                    txBytes: 0,
                    timestamp: Date(timeIntervalSince1970: 1)
                )
            ]
        ])
        let sampler = NetworkThroughputSampler(counterReader: sequence.next)

        _ = sampler.sample()
        let throughput = sampler.sample()

        XCTAssertEqual(throughput.downloadMbps ?? -1, 0.008, accuracy: 0.0001)
    }
}

private final class InterfaceCounterSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [[InterfaceCounters]?]

    init(samples: [[InterfaceCounters]?]) {
        self.samples = samples
    }

    func next() -> [InterfaceCounters]? {
        lock.lock()
        defer { lock.unlock() }

        guard !samples.isEmpty else { return nil }
        return samples.removeFirst()
    }
}
