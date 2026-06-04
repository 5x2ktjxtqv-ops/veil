import Foundation

final class MullvadStabilityTracker: @unchecked Sendable {
    private struct Observation: Equatable {
        var connection: VPNConnectionState
        var sampledAt: Date
    }

    private let rollingWindow: TimeInterval
    private let enterTransitionCount: Int
    private let exitTransitionCount: Int

    private var observations: [Observation] = []
    private var isFlapping = false

    init(
        rollingWindow: TimeInterval = 120,
        enterTransitionCount: Int = 3,
        exitTransitionCount: Int = 1
    ) {
        self.rollingWindow = rollingWindow
        self.enterTransitionCount = enterTransitionCount
        self.exitTransitionCount = exitTransitionCount
    }

    func reset() {
        observations = []
        isFlapping = false
    }

    func update(
        _ status: VPNStatus,
        recordsObservation: Bool = true,
        at date: Date
    ) -> VPNStatus {
        if recordsObservation, isConnectionObservationEligible(status.connection) {
            observations.append(Observation(connection: status.connection, sampledAt: date))
        }

        pruneObservations(at: date)
        let transitionCount = Self.transitionCount(in: observations.map(\.connection))

        if isFlapping {
            isFlapping = transitionCount > exitTransitionCount
        } else {
            isFlapping = transitionCount >= enterTransitionCount
        }

        var decorated = status
        if isFlapping, !status.stability.overridesMeasuredStability {
            decorated.stabilityOverride = .flapping
            decorated.flapCount = max(transitionCount, enterTransitionCount)
        } else {
            decorated.stabilityOverride = nil
            decorated.flapCount = nil
        }

        return decorated
    }

    private func pruneObservations(at date: Date) {
        let cutoff = date.addingTimeInterval(-rollingWindow)
        observations.removeAll { $0.sampledAt < cutoff }
    }

    private func isConnectionObservationEligible(_ connection: VPNConnectionState) -> Bool {
        switch connection {
        case .connected, .connecting, .disconnected:
            return true
        case .error, .unknown:
            return false
        }
    }

    private static func transitionCount(in states: [VPNConnectionState]) -> Int {
        guard states.count > 1 else { return 0 }

        var transitions = 0
        var previous = states[0]

        for state in states.dropFirst() {
            if state != previous {
                transitions += 1
                previous = state
            }
        }

        return transitions
    }
}
