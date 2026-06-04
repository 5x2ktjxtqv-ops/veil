import Foundation

#if DEBUG
extension MockTelemetryConfiguration {
    var snapshot: VeilSnapshot {
        fixture.snapshot
    }

    var hudConfiguration: StatusHUDConfiguration {
        fixture.hudConfiguration
    }
}

extension MockTelemetryFixture {
    var snapshot: VeilSnapshot {
        switch self {
        case .defaultCompact:
            return PreviewFixtures.defaultCompact
        case .fullExpanded:
            return PreviewFixtures.fullExpanded
        case .cpuTemperatureUnavailable:
            return PreviewFixtures.cpuTemperatureUnavailable
        case .modelGrowthCompact:
            return PreviewFixtures.modelGrowthCompact
        case .vpnOff:
            return PreviewFixtures.vpnOff
        case .approvalRequired:
            return PreviewFixtures.approvalRequired
        case .memoryElevated:
            return PreviewFixtures.memoryElevated
        case .memoryHigh:
            return PreviewFixtures.memoryHigh
        case .latencyDegraded:
            return PreviewFixtures.latencyDegraded
        case .networkUnknown:
            return PreviewFixtures.networkUnknown
        }
    }

    var hudConfiguration: StatusHUDConfiguration {
        switch self {
        case .fullExpanded:
            return .expanded420
        case .defaultCompact, .cpuTemperatureUnavailable, .modelGrowthCompact, .vpnOff, .approvalRequired, .memoryElevated, .memoryHigh, .latencyDegraded, .networkUnknown:
            return .notchCapsule
        }
    }
}
#endif
