import XCTest
@testable import Veil

final class CPUUsageSamplerTests: XCTestCase {
    func testUsagePercentShowsBusyTimeAsUserSystemAndNiceOverTotal() {
        let previous = CPUTimeTicks(user: 100, system: 50, idle: 200, nice: 10)
        let current = CPUTimeTicks(user: 130, system: 70, idle: 240, nice: 20)

        XCTAssertEqual(CPUUsageSampler.usagePercent(from: previous, to: current), 60)
    }

    func testUsagePercentIsComplementOfIdleShare() {
        let previous = CPUTimeTicks(user: 0, system: 0, idle: 0, nice: 0)
        let current = CPUTimeTicks(user: 15, system: 25, idle: 60, nice: 0)

        XCTAssertEqual(CPUUsageSampler.usagePercent(from: previous, to: current), 40)
    }

    func testUsagePercentReturnsNilForCounterRegression() {
        let previous = CPUTimeTicks(user: 100, system: 50, idle: 200, nice: 10)
        let current = CPUTimeTicks(user: 90, system: 40, idle: 190, nice: 5)

        XCTAssertNil(CPUUsageSampler.usagePercent(from: previous, to: current))
    }

    func testProcessInfoThermalStatesMapToCPUPressure() {
        XCTAssertEqual(ProcessInfoThermalPressureProvider.pressure(from: .nominal), .nominal)
        XCTAssertEqual(ProcessInfoThermalPressureProvider.pressure(from: .fair), .fair)
        XCTAssertEqual(ProcessInfoThermalPressureProvider.pressure(from: .serious), .serious)
        XCTAssertEqual(ProcessInfoThermalPressureProvider.pressure(from: .critical), .critical)
    }
}
