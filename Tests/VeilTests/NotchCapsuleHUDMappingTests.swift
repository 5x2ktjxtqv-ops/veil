import XCTest
@testable import Veil

final class NotchCapsuleHUDMappingTests: XCTestCase {
    func testProductionDefaultUsesShrunkenNotchCapsuleMapping() {
        XCTAssertEqual(StatusHUDConfiguration.productionCompact.mode, .notchCapsule)
        XCTAssertEqual(StatusHUDConfiguration.productionCompact.width, 320)
        XCTAssertEqual(StatusHUDConfiguration.productionCompact.height, 32)
        XCTAssertNotEqual(StatusHUDConfiguration.productionCompact.mode, .compact)
        XCTAssertNotEqual(StatusHUDConfiguration.productionCompact.mode, .expanded)
    }

    func testRotationAdvancesEveryThreeSeconds() {
        XCTAssertEqual(StatusHUDMapping.notchCapsuleLaneRotationInterval, 3)
        XCTAssertEqual(StatusHUDMapping.notchCapsuleLane(at: Date(timeIntervalSince1970: 0)), .memory)
        XCTAssertEqual(StatusHUDMapping.notchCapsuleLane(at: Date(timeIntervalSince1970: 2.99)), .memory)
        XCTAssertEqual(StatusHUDMapping.notchCapsuleLane(at: Date(timeIntervalSince1970: 3)), .cpu)
        XCTAssertEqual(StatusHUDMapping.notchCapsuleLane(at: Date(timeIntervalSince1970: 5.99)), .cpu)
        XCTAssertEqual(StatusHUDMapping.notchCapsuleLane(at: Date(timeIntervalSince1970: 6)), .network)
        XCTAssertEqual(StatusHUDMapping.notchCapsuleLane(at: Date(timeIntervalSince1970: 9)), .memory)
    }

    func testDefaultNotchCapsuleLanesUsePublicLocalSignals() {
        XCTAssertEqual(StatusHUDMapping.notchCapsuleLanes(for: snapshot(vpn: Self.restrictedVPN())).map(\.id), [
            .memory,
            .cpu,
            .network
        ])
    }

    func testApprovedMullvadExtendsRotationAfterPublicLocalSignals() {
        XCTAssertEqual(StatusHUDMapping.notchCapsuleLanes(for: snapshot()).map(\.id), [
            .memory,
            .cpu,
            .network,
            .vpn
        ])

        XCTAssertEqual(
            StatusHUDMapping.notchCapsuleLanes(for: snapshot(modelGrowth: modelGrowthStatus(color: .green))).map(\.id),
            [
                .memory,
                .cpu,
                .network,
                .vpn,
                .modelGrowthWorkload
            ]
        )

        XCTAssertEqual(StatusHUDMapping.notchCapsuleLanes(for: snapshot(memory: Self.memory(pressure: .elevated))).map(\.id), [
            .memory,
            .cpu,
            .network,
            .vpn
        ])

        XCTAssertEqual(
            StatusHUDMapping.notchCapsuleLanes(
                for: snapshot(cpu: CPUStatus(usagePercent: 82, temperatureCelsius: nil, thermalPressure: .nominal, usageHealth: .elevated))
            ).map(\.id),
            [
                .memory,
                .cpu,
                .network,
                .vpn
            ]
        )
    }

    func testVPNLaneShowsLocationAndCurrentThroughputWithoutLabels() {
        let mapping = StatusHUDMapping.notchCapsuleMetrics(for: snapshot(), lane: .vpn)

        XCTAssertEqual(mapping.lane, .vpn)
        XCTAssertEqual(mapping.source, "mullvad")
        XCTAssertEqual(mapping.leftWing, [
            HUDMetric(id: "vpn-primary", label: "", value: "FRA", role: .normal)
        ])
        XCTAssertEqual(mapping.rightWing, [
            HUDMetric(id: "vpn-quality", label: "", value: "312M", role: .normal)
        ])
        XCTAssertEqual(mapping.severity, HUDMetricRole.neutral)
        assertNoFieldNames(mapping)
        assertNotchVoidIsEmpty(mapping)
    }

    func testVPNLaneShowsConnectedDegradedWithoutColoringThroughputWarning() {
        let mapping = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(vpn: Self.vpn(latencyMs: 182, downloadMbps: 0, nodeHealth: .degraded)),
            lane: .vpn
        )

        XCTAssertEqual(mapping.leftWing, [
            HUDMetric(id: "vpn-primary", label: "", value: "FRA", role: .warning)
        ])
        XCTAssertEqual(mapping.rightWing, [
            HUDMetric(id: "vpn-quality", label: "", value: "0K", role: .normal)
        ])
        XCTAssertEqual(mapping.severity, HUDMetricRole.warning)
        assertNoFieldNames(mapping)
        assertNotchVoidIsEmpty(mapping)
    }

    func testVPNLaneUsesPathSpeedFromVPNStatus() {
        var vpn = Self.vpn(downloadMbps: nil)
        vpn.pathSpeed = .measured(
            downloadMbps: 18.4,
            source: .passiveTunnel,
            measuredAt: Date(timeIntervalSince1970: 0)
        )

        let mapping = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(
                vpn: vpn,
                network: NetworkThroughput(downloadMbps: 99.9, uploadMbps: 2.1)
            ),
            lane: .vpn
        )

        XCTAssertEqual(mapping.leftWing, [
            HUDMetric(id: "vpn-primary", label: "", value: "FRA", role: .normal)
        ])
        XCTAssertEqual(mapping.rightWing, [
            HUDMetric(id: "vpn-quality", label: "", value: "18M", role: .normal)
        ])
        XCTAssertEqual(mapping.severity, HUDMetricRole.neutral)
        assertNoFieldNames(mapping)
        assertNotchVoidIsEmpty(mapping)
    }

    func testVPNLaneShowsPathSpeedProbeStates() {
        var idle = Self.vpn(downloadMbps: nil)
        idle.pathSpeed = .idle(measuredAt: Date(timeIntervalSince1970: 0))
        let idleMapping = StatusHUDMapping.notchCapsuleMetrics(for: snapshot(vpn: idle), lane: .vpn)

        var slow = Self.vpn(downloadMbps: nil)
        slow.pathSpeed = .measured(
            downloadMbps: 0.42,
            quality: .slow,
            source: .activeProbe,
            measuredAt: Date(timeIntervalSince1970: 0)
        )
        let slowMapping = StatusHUDMapping.notchCapsuleMetrics(for: snapshot(vpn: slow), lane: .vpn)

        var failed = Self.vpn(downloadMbps: nil)
        failed.pathSpeed = .failed(reason: .timeout, measuredAt: Date(timeIntervalSince1970: 0))
        let failedMapping = StatusHUDMapping.notchCapsuleMetrics(for: snapshot(vpn: failed), lane: .vpn)

        XCTAssertEqual(idleMapping.rightWing, [
            HUDMetric(id: "vpn-quality", label: "", value: "IDLE", role: .muted)
        ])
        XCTAssertEqual(slowMapping.rightWing, [
            HUDMetric(id: "vpn-quality", label: "", value: "420K", role: .warning)
        ])
        XCTAssertEqual(failedMapping.rightWing, [
            HUDMetric(id: "vpn-quality", label: "", value: "TMO", role: .warning)
        ])
    }

    func testVPNLaneShowsDisconnectedAsOff() {
        let mapping = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(vpn: Self.vpn(connection: .disconnected, cityCode: nil, latencyMs: nil, nodeHealth: .unknown)),
            lane: .vpn
        )

        XCTAssertEqual(mapping.leftWing, [
            HUDMetric(id: "vpn-primary", label: "", value: "OFF", role: .critical)
        ])
        XCTAssertEqual(mapping.rightWing, [
            HUDMetric(id: "vpn-quality", label: "", value: "--", role: .muted)
        ])
        XCTAssertEqual(mapping.severity, HUDMetricRole.critical)
        assertNoFieldNames(mapping)
        assertNotchVoidIsEmpty(mapping)
    }

    func testVPNLaneShowsFlappingTransitionCount() {
        let mapping = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(vpn: Self.vpn(stability: .flapping, flapCount: 3)),
            lane: .vpn
        )

        XCTAssertEqual(mapping.leftWing, [
            HUDMetric(id: "vpn-primary", label: "", value: "FLAP", role: .warning)
        ])
        XCTAssertEqual(mapping.rightWing, [
            HUDMetric(id: "vpn-quality", label: "", value: "3x", role: .warning)
        ])
        XCTAssertEqual(mapping.severity, HUDMetricRole.warning)
        assertNoFieldNames(mapping)
        assertNotchVoidIsEmpty(mapping)
    }

    func testVPNLaneShowsConnectingTransient() {
        let mapping = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(vpn: Self.vpn(connection: .connecting, cityCode: nil, latencyMs: nil, nodeHealth: .unknown)),
            lane: .vpn
        )

        XCTAssertEqual(mapping.leftWing, [
            HUDMetric(id: "vpn-primary", label: "", value: "...", role: .normal)
        ])
        XCTAssertEqual(mapping.rightWing, [
            HUDMetric(id: "vpn-quality", label: "", value: "--", role: .muted)
        ])
        XCTAssertEqual(mapping.severity, HUDMetricRole.neutral)
        assertNoFieldNames(mapping)
        assertNotchVoidIsEmpty(mapping)
    }

    func testVPNLaneShowsCliErrorAsErr() {
        let mapping = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(vpn: Self.vpn(connection: .error, cityCode: nil, latencyMs: nil, nodeHealth: .unknown, errorReason: .commandFailed)),
            lane: .vpn
        )

        XCTAssertEqual(mapping.leftWing, [
            HUDMetric(id: "vpn-primary", label: "", value: "ERR", role: .warning)
        ])
        XCTAssertEqual(mapping.rightWing, [
            HUDMetric(id: "vpn-quality", label: "", value: "--", role: .muted)
        ])
        XCTAssertEqual(mapping.severity, HUDMetricRole.warning)
        assertNoFieldNames(mapping)
        assertNotchVoidIsEmpty(mapping)
    }

    func testMemoryLaneShowsRamAndSwapWithoutLabels() {
        let mapping = StatusHUDMapping.notchCapsuleMetrics(for: snapshot(), lane: .memory)

        XCTAssertEqual(mapping.lane, .memory)
        XCTAssertEqual(mapping.source, "memory")
        XCTAssertEqual(mapping.leftWing, [
            HUDMetric(id: "mem-primary", label: "", value: "18G", role: .normal)
        ])
        XCTAssertEqual(mapping.rightWing, [
            HUDMetric(id: "mem-pressure", label: "", value: "2.1G", role: .normal)
        ])
        XCTAssertEqual(mapping.severity, HUDMetricRole.neutral)
        assertNoFieldNames(mapping)
        assertNotchVoidIsEmpty(mapping)
    }

    func testMemoryLaneDoesNotDisplayCachedFiles() {
        let mapping = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(memory: Self.memory(usedGiB: 12, cachedGiB: 9, swapGiB: 0.8)),
            lane: .memory
        )

        XCTAssertEqual(mapping.leftWing, [
            HUDMetric(id: "mem-primary", label: "", value: "12G", role: .normal)
        ])
        XCTAssertEqual(mapping.rightWing, [
            HUDMetric(id: "mem-pressure", label: "", value: "0.8G", role: .normal)
        ])
        assertNoFieldNames(mapping)
        assertNotchVoidIsEmpty(mapping)
    }

    func testMemoryPressureDrivesWarningAndCriticalColors() {
        let elevated = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(memory: Self.memory(pressure: .elevated)),
            lane: .memory
        )
        let high = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(memory: Self.memory(pressure: .high)),
            lane: .memory
        )

        XCTAssertEqual(elevated.leftWing.first?.role, .warning)
        XCTAssertEqual(elevated.rightWing.first?.role, .warning)
        XCTAssertEqual(elevated.severity, .warning)
        XCTAssertEqual(high.leftWing.first?.role, .critical)
        XCTAssertEqual(high.rightWing.first?.role, .critical)
        XCTAssertEqual(high.severity, .critical)
        assertNoFieldNames(elevated)
        assertNoFieldNames(high)
        assertNotchVoidIsEmpty(elevated)
        assertNotchVoidIsEmpty(high)
    }

    func testCPULaneShowsUsageAndThermalPressureWithoutLabels() {
        let mapping = StatusHUDMapping.notchCapsuleMetrics(for: snapshot(), lane: .cpu)

        XCTAssertEqual(mapping.lane, .cpu)
        XCTAssertEqual(mapping.source, "cpu")
        XCTAssertEqual(mapping.leftWing, [
            HUDMetric(id: "cpu-primary", label: "", value: "18%", role: .normal)
        ])
        XCTAssertEqual(mapping.rightWing, [
            HUDMetric(id: "cpu-quality", label: "", value: "OK", role: .normal)
        ])
        XCTAssertEqual(mapping.severity, HUDMetricRole.neutral)
        assertNoFieldNames(mapping)
        assertNotchVoidIsEmpty(mapping)
    }

    func testNetworkLaneShowsPassiveDownloadAndUploadWithoutLabels() {
        let mapping = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(network: NetworkThroughput(downloadMbps: 99.9, uploadMbps: 2.1)),
            lane: .network
        )

        XCTAssertEqual(mapping.lane, .network)
        XCTAssertEqual(mapping.source, "network")
        XCTAssertEqual(mapping.leftWing, [
            HUDMetric(id: "network-download", label: "", value: "100M", role: .normal)
        ])
        XCTAssertEqual(mapping.rightWing, [
            HUDMetric(id: "network-upload", label: "", value: "2M", role: .normal)
        ])
        XCTAssertEqual(mapping.severity, .neutral)
        assertNoFieldNames(mapping)
        assertNotchVoidIsEmpty(mapping)
    }

    func testCPUThermalPressureUnknownShowsDoubleDash() {
        let mapping = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(cpu: CPUStatus(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .unknown)),
            lane: .cpu
        )

        XCTAssertEqual(mapping.leftWing, [
            HUDMetric(id: "cpu-primary", label: "", value: "18%", role: .normal)
        ])
        XCTAssertEqual(mapping.rightWing, [
            HUDMetric(id: "cpu-quality", label: "", value: "--", role: .muted)
        ])
        XCTAssertEqual(mapping.severity, HUDMetricRole.neutral)
        assertNoFieldNames(mapping)
        assertNotchVoidIsEmpty(mapping)
    }

    func testCPUUsageAndThermalPressureUseIndependentColors() {
        let fair = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(cpu: CPUStatus(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .fair)),
            lane: .cpu
        )
        let serious = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(cpu: CPUStatus(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .serious)),
            lane: .cpu
        )
        let critical = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(cpu: CPUStatus(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .critical)),
            lane: .cpu
        )

        XCTAssertEqual(fair.leftWing, [
            HUDMetric(id: "cpu-primary", label: "", value: "18%", role: .normal)
        ])
        XCTAssertEqual(fair.rightWing, [
            HUDMetric(id: "cpu-quality", label: "", value: "WARM", role: .warning)
        ])
        XCTAssertEqual(fair.severity, .warning)
        XCTAssertEqual(serious.leftWing, [
            HUDMetric(id: "cpu-primary", label: "", value: "18%", role: .normal)
        ])
        XCTAssertEqual(serious.rightWing, [
            HUDMetric(id: "cpu-quality", label: "", value: "HOT", role: .warning)
        ])
        XCTAssertEqual(serious.severity, .warning)
        XCTAssertEqual(critical.leftWing, [
            HUDMetric(id: "cpu-primary", label: "", value: "18%", role: .normal)
        ])
        XCTAssertEqual(critical.rightWing, [
            HUDMetric(id: "cpu-quality", label: "", value: "CRIT", role: .critical)
        ])
        XCTAssertEqual(critical.severity, .critical)
        assertNoFieldNames(fair)
        assertNoFieldNames(serious)
        assertNoFieldNames(critical)
        assertNotchVoidIsEmpty(fair)
        assertNotchVoidIsEmpty(serious)
        assertNotchVoidIsEmpty(critical)
    }

    func testOverallSeverityIncludesCPUThermalPressure() {
        let warning = snapshot(
            cpu: CPUStatus(usagePercent: nil, temperatureCelsius: nil, thermalPressure: .serious)
        )
        let critical = snapshot(
            cpu: CPUStatus(usagePercent: nil, temperatureCelsius: nil, thermalPressure: .critical)
        )

        XCTAssertEqual(StatusHUDMapping.severity(for: warning), .warning)
        XCTAssertEqual(StatusHUDMapping.severity(for: critical), .critical)
    }

    func testOverallSeverityIncludesPowerKeepAliveState() {
        let degraded = snapshot(powerKeepAlive: PowerKeepAliveSnapshot(
            mode: .systemPolicy,
            state: .degraded,
            activeAssertions: PowerAssertionKind.backgroundTaskSet,
            systemPolicyStatus: nil,
            checkedAt: Date(timeIntervalSince1970: 0)
        ))
        let failed = snapshot(powerKeepAlive: PowerKeepAliveSnapshot(
            mode: .systemPolicy,
            state: .failed,
            activeAssertions: [],
            systemPolicyStatus: nil,
            checkedAt: Date(timeIntervalSince1970: 0)
        ))

        XCTAssertEqual(StatusHUDMapping.severity(for: degraded), .warning)
        XCTAssertEqual(StatusHUDMapping.severity(for: failed), .critical)
    }

    func testOverallSeverityIncludesTaskStatusFailure() {
        XCTAssertEqual(
            StatusHUDMapping.severity(for: snapshot(taskStatus: TaskStatusSnapshot(
                state: .attention,
                label: "codex",
                detail: nil,
                updatedAt: Date(timeIntervalSince1970: 0)
            ))),
            .warning
        )
        XCTAssertEqual(
            StatusHUDMapping.severity(for: snapshot(taskStatus: TaskStatusSnapshot(
                state: .failed,
                label: "codex",
                detail: nil,
                updatedAt: Date(timeIntervalSince1970: 0)
            ))),
            .critical
        )
    }

    func testPowerKeepAliveAssertedRendersRightIndicator() {
        let mapping = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(powerKeepAlive: PowerKeepAliveSnapshot(
                mode: .assertions,
                state: .asserted,
                activeAssertions: PowerAssertionKind.backgroundTaskSet,
                systemPolicyStatus: nil,
                checkedAt: Date(timeIntervalSince1970: 0)
            )),
            lane: .vpn
        )

        XCTAssertEqual(mapping.indicator(on: .right), HUDIndicator(color: .green, pulse: .none, steadyOpacity: 0.96))
        XCTAssertNil(mapping.indicator(on: .left))
    }

    func testInactivePowerKeepAliveDoesNotRenderRightIndicator() {
        let mapping = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(powerKeepAlive: .inactive),
            lane: .vpn
        )

        XCTAssertNil(mapping.indicator(on: .right))
    }

    func testTaskStatusRendersLeftIndicatorWithoutExtendingLaneRotation() {
        let taskStatus = TaskStatusSnapshot(
            state: .running,
            label: "codex",
            detail: "swift test",
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let mapping = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(taskStatus: taskStatus),
            lane: .network
        )

        XCTAssertEqual(StatusHUDMapping.notchCapsuleLanes(for: snapshot(taskStatus: taskStatus)).map(\.id), [
            .memory,
            .cpu,
            .network,
            .vpn
        ])
        XCTAssertEqual(mapping.indicator(on: .left), HUDIndicator(color: .yellow, pulse: .medium))
        XCTAssertNil(mapping.indicator(on: .right))
    }

    func testTaskStatusDoneAndFailedDriveLeftIndicatorColor() {
        let succeeded = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(taskStatus: TaskStatusSnapshot(
                state: .succeeded,
                label: "codex",
                detail: nil,
                updatedAt: Date(timeIntervalSince1970: 0)
            )),
            lane: .network
        )
        let failed = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(taskStatus: TaskStatusSnapshot(
                state: .failed,
                label: "codex",
                detail: nil,
                updatedAt: Date(timeIntervalSince1970: 0)
            )),
            lane: .network
        )

        XCTAssertEqual(succeeded.indicator(on: .left), HUDIndicator(color: .green, pulse: .none, steadyOpacity: 0.96))
        XCTAssertEqual(failed.indicator(on: .left), HUDIndicator(color: .red, pulse: .fast))
    }

    func testCPUUsageHealthDrivesWarningAndCriticalColors() {
        let elevated = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(cpu: CPUStatus(usagePercent: 82, temperatureCelsius: nil, thermalPressure: .nominal, usageHealth: .elevated)),
            lane: .cpu
        )
        let high = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(cpu: CPUStatus(usagePercent: 96, temperatureCelsius: nil, thermalPressure: .nominal, usageHealth: .high)),
            lane: .cpu
        )

        XCTAssertEqual(elevated.leftWing, [
            HUDMetric(id: "cpu-primary", label: "", value: "82%", role: .warning)
        ])
        XCTAssertEqual(elevated.rightWing, [
            HUDMetric(id: "cpu-quality", label: "", value: "OK", role: .normal)
        ])
        XCTAssertEqual(elevated.severity, .warning)
        XCTAssertEqual(high.leftWing, [
            HUDMetric(id: "cpu-primary", label: "", value: "96%", role: .critical)
        ])
        XCTAssertEqual(high.rightWing, [
            HUDMetric(id: "cpu-quality", label: "", value: "OK", role: .normal)
        ])
        XCTAssertEqual(high.severity, .critical)
        assertNoFieldNames(elevated)
        assertNoFieldNames(high)
        assertNotchVoidIsEmpty(elevated)
        assertNotchVoidIsEmpty(high)
    }

    func testModelGrowthCompactStatusShowsWorkloadPairWithHeartbeatIndicator() {
        let vpn = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(modelGrowth: modelGrowthStatus(color: .green)),
            lane: .vpn
        )
        let workload = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(modelGrowth: modelGrowthStatus(color: .green)),
            lane: .modelGrowthWorkload
        )

        XCTAssertEqual(vpn.leftWing, [
            HUDMetric(id: "vpn-primary", label: "", value: "FRA", role: .normal)
        ])
        XCTAssertEqual(vpn.rightWing, [
            HUDMetric(id: "vpn-quality", label: "", value: "312M", role: .normal)
        ])
        XCTAssertEqual(vpn.indicator, HUDIndicator(color: .green, pulse: .none, steadyOpacity: 0.96))
        XCTAssertNil(vpn.indicator(on: .right))
        XCTAssertEqual(workload.source, "model-growth")
        XCTAssertEqual(workload.indicator, HUDIndicator(color: .green, pulse: .none, steadyOpacity: 0.96))
        XCTAssertEqual(workload.leftWing, [
            HUDMetric(id: "model-growth-workload-left", label: "", value: "LGT", role: .normal)
        ])
        XCTAssertEqual(workload.rightWing, [
            HUDMetric(id: "model-growth-workload-right", label: "", value: "USR", role: .normal)
        ])
        XCTAssertEqual(workload.severity, .neutral)
        assertNoFieldNames(workload)
        assertNotchVoidIsEmpty(workload)
    }

    func testModelGrowthExtendsRotationWithWorkloadOnlyAfterBaseLanes() {
        let snapshot = snapshot(modelGrowth: modelGrowthStatus(color: .green))

        XCTAssertEqual(StatusHUDMapping.notchCapsuleLane(for: snapshot, at: Date(timeIntervalSince1970: 0)), .memory)
        XCTAssertEqual(StatusHUDMapping.notchCapsuleLane(for: snapshot, at: Date(timeIntervalSince1970: 3)), .cpu)
        XCTAssertEqual(StatusHUDMapping.notchCapsuleLane(for: snapshot, at: Date(timeIntervalSince1970: 6)), .network)
        XCTAssertEqual(StatusHUDMapping.notchCapsuleLane(for: snapshot, at: Date(timeIntervalSince1970: 9)), .vpn)
        XCTAssertEqual(StatusHUDMapping.notchCapsuleLane(for: snapshot, at: Date(timeIntervalSince1970: 12)), .modelGrowthWorkload)
        XCTAssertEqual(StatusHUDMapping.notchCapsuleLane(for: snapshot, at: Date(timeIntervalSince1970: 15)), .memory)
    }

    func testModelGrowthWorkloadStatusesDoNotDriveRedPairTextColors() {
        let deepWorkload = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(modelGrowth: modelGrowthStatus(
                color: .green,
                workload: ModelGrowthCompactField(id: "workload", left: "DEE", right: "OKA")
            )),
            lane: .modelGrowthWorkload
        )
        let observedWorkload = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(modelGrowth: modelGrowthStatus(
                color: .green,
                workload: ModelGrowthCompactField(id: "workload", left: "OBS", right: "USR")
            )),
            lane: .modelGrowthWorkload
        )
        let unknownWorkload = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(modelGrowth: modelGrowthStatus(
                color: .green,
                workload: ModelGrowthCompactField(id: "workload", left: "UNK", right: "UNK")
            )),
            lane: .modelGrowthWorkload
        )

        XCTAssertEqual(deepWorkload.leftWing.first?.role, .normal)
        XCTAssertEqual(deepWorkload.rightWing.first?.role, .normal)
        XCTAssertEqual(observedWorkload.leftWing.first?.role, .normal)
        XCTAssertEqual(observedWorkload.rightWing.first?.role, .normal)
        XCTAssertEqual(unknownWorkload.leftWing.first?.role, .muted)
        XCTAssertEqual(unknownWorkload.rightWing.first?.role, .muted)
    }

    func testModelGrowthIndicatorColorDrivesSeverity() {
        let yellow = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(modelGrowth: modelGrowthStatus(color: .yellow)),
            lane: .modelGrowthWorkload
        )
        let red = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(modelGrowth: modelGrowthStatus(color: .red)),
            lane: .modelGrowthWorkload
        )
        let unknown = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(modelGrowth: modelGrowthStatus(color: .unknown)),
            lane: .modelGrowthWorkload
        )

        XCTAssertEqual(yellow.indicator, HUDIndicator(color: .yellow, pulse: .medium))
        XCTAssertEqual(yellow.severity, .warning)
        XCTAssertEqual(red.indicator, HUDIndicator(color: .red, pulse: .fast))
        XCTAssertEqual(red.severity, .critical)
        XCTAssertEqual(unknown.indicator, HUDIndicator(color: .yellow, pulse: .medium))
        XCTAssertEqual(unknown.severity, .warning)
    }

    func testApprovalRequiredVPNLaneDoesNotReintroduceFieldNames() {
        let mapping = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(vpn: VPNStatus.approvalRequired(downloadMbps: nil)),
            lane: .vpn
        )

        XCTAssertEqual(mapping.leftWing, [
            HUDMetric(id: "vpn-primary", label: "", value: "--", role: .muted)
        ])
        XCTAssertEqual(mapping.rightWing, [
            HUDMetric(id: "vpn-quality", label: "", value: "--", role: .muted)
        ])
        XCTAssertEqual(mapping.severity, HUDMetricRole.neutral)
        assertNoFieldNames(mapping)
        assertNotchVoidIsEmpty(mapping)
    }

    func testApprovalDeniedVPNLaneUsesMutedRestrictedFallback() {
        var vpn = VPNStatus.approvalRequired(downloadMbps: nil)
        vpn.errorReason = .approvalDenied

        let mapping = StatusHUDMapping.notchCapsuleMetrics(
            for: snapshot(vpn: vpn),
            lane: .vpn
        )

        XCTAssertEqual(mapping.leftWing, [
            HUDMetric(id: "vpn-primary", label: "", value: "--", role: .muted)
        ])
        XCTAssertEqual(mapping.rightWing, [
            HUDMetric(id: "vpn-quality", label: "", value: "--", role: .muted)
        ])
        XCTAssertEqual(mapping.severity, HUDMetricRole.neutral)
        assertNoFieldNames(mapping)
        assertNotchVoidIsEmpty(mapping)
    }

    private func assertNoFieldNames(
        _ mapping: NotchCapsuleHUDMapping,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let forbiddenTerms = ["VPN", "RAM", "MEM", "SWAP", "CPU", "LOAD"]
        let metrics = mapping.leftWing + mapping.notchVoid + mapping.rightWing

        for metric in metrics {
            XCTAssertTrue(metric.label.isEmpty, file: file, line: line)

            for term in forbiddenTerms {
                XCTAssertFalse(
                    metric.value.uppercased().contains(term),
                    "Notch capsule value should not include field name \(term): \(metric.value)",
                    file: file,
                    line: line
                )
            }
        }
    }

    private func assertNotchVoidIsEmpty(
        _ mapping: NotchCapsuleHUDMapping,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(mapping.notchVoid.isEmpty, "No live text belongs in the physical notch cover.", file: file, line: line)
        XCTAssertEqual(mapping.leftWing.count + mapping.rightWing.count, 2, file: file, line: line)
    }

    private func snapshot(
        memory: MemoryStatus = memory(),
        vpn: VPNStatus = vpn(),
        network: NetworkThroughput = NetworkThroughput(downloadMbps: nil, uploadMbps: nil),
        cpu: CPUStatus = CPUStatus(usagePercent: 18, temperatureCelsius: nil, thermalPressure: .nominal),
        taskStatus: TaskStatusSnapshot = .inactive,
        modelGrowth: ModelGrowthCompactStatus? = nil,
        powerKeepAlive: PowerKeepAliveSnapshot = .inactive
    ) -> VeilSnapshot {
        VeilSnapshot(
            memory: memory,
            vpn: vpn,
            network: network,
            cpu: cpu,
            taskStatus: taskStatus,
            modelGrowth: modelGrowth,
            powerKeepAlive: powerKeepAlive,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func modelGrowthStatus(
        color: ModelGrowthIndicatorColor,
        workload: ModelGrowthCompactField = ModelGrowthCompactField(id: "workload", left: "LGT", right: "USR")
    ) -> ModelGrowthCompactStatus {
        ModelGrowthCompactStatus(
            indicator: ModelGrowthIndicator(color: color, code: nil, state: nil, reason: nil),
            fields: [
                ModelGrowthCompactField(id: "heartbeat", left: "LIV", right: "OKA"),
                workload
            ],
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private static func memory(
        pressure: HealthLevel = .normal,
        usedGiB: Double = 18,
        cachedGiB: Double = 4,
        swapGiB: Double = 2.1
    ) -> MemoryStatus {
        MemoryStatus(
            totalBytes: bytes(32),
            usedBytes: bytes(usedGiB),
            cachedFilesBytes: bytes(cachedGiB),
            swapUsedBytes: bytes(swapGiB),
            pressure: pressure
        )
    }

    private static func vpn(
        connection: VPNConnectionState = .connected,
        cityCode: String? = "FRA",
        latencyMs: Double? = 23.4,
        downloadMbps: Double? = 312.3,
        nodeHealth: VPNNodeHealth = .normal,
        errorReason: VPNStatusErrorReason? = nil,
        stability: VPNStabilityState? = nil,
        flapCount: Int? = nil
    ) -> VPNStatus {
        VPNStatus(
            connection: connection,
            countryCode: cityCode == nil ? nil : "DE",
            cityCode: cityCode,
            relayName: cityCode == nil ? nil : "de-fra-wg-001",
            visibleLocation: cityCode == nil ? nil : "Germany, Frankfurt.",
            latencyMs: latencyMs,
            downloadMbps: downloadMbps,
            nodeHealth: nodeHealth,
            errorReason: errorReason,
            sampledAt: Date(timeIntervalSince1970: 0),
            stability: stability,
            flapCount: flapCount
        )
    }

    private static func restrictedVPN() -> VPNStatus {
        VPNStatus.approvalRequired(downloadMbps: nil)
    }

    private static func bytes(_ gibibytes: Double) -> UInt64 {
        UInt64(gibibytes * 1_073_741_824.0)
    }
}
