import XCTest
@testable import Veil

final class BackgroundTaskPowerKeeperTests: XCTestCase {
    func testStartCreatesBackgroundTaskPowerAssertions() {
        let manager = RecordingPowerAssertionManager()
        let keeper = BackgroundTaskPowerKeeper(
            configuration: PowerKeepAliveConfiguration(isEnabled: true),
            manager: manager
        )

        let status = keeper.start()

        XCTAssertTrue(status.isEnabled)
        XCTAssertEqual(status.activeAssertions, PowerAssertionKind.backgroundTaskSet)
        XCTAssertTrue(status.failures.isEmpty)
        XCTAssertNil(status.systemPolicyStatus)
        XCTAssertEqual(manager.createdKinds(), PowerAssertionKind.backgroundTaskSet)
    }

    func testStartDoesNotCreateAssertionsWhenDisabled() {
        let manager = RecordingPowerAssertionManager()
        let keeper = BackgroundTaskPowerKeeper(
            configuration: PowerKeepAliveConfiguration(isEnabled: false),
            manager: manager
        )

        let status = keeper.start()

        XCTAssertEqual(status, .disabled)
        XCTAssertTrue(manager.createdKinds().isEmpty)
    }

    func testStartIsIdempotentAndDoesNotDuplicateAssertions() {
        let manager = RecordingPowerAssertionManager()
        let keeper = BackgroundTaskPowerKeeper(
            configuration: PowerKeepAliveConfiguration(isEnabled: true),
            manager: manager
        )

        _ = keeper.start()
        _ = keeper.start()

        XCTAssertEqual(manager.createdKinds(), PowerAssertionKind.backgroundTaskSet)
    }

    func testStopReleasesAssertionsInReverseOrder() {
        let manager = RecordingPowerAssertionManager()
        let keeper = BackgroundTaskPowerKeeper(
            configuration: PowerKeepAliveConfiguration(isEnabled: true),
            manager: manager
        )

        _ = keeper.start()
        keeper.stop()

        XCTAssertEqual(manager.releasedKinds(), Array(PowerAssertionKind.backgroundTaskSet.reversed()))
    }

    func testFailedAssertionKeepsSuccessfulAssertionsAndReportsFailure() {
        let manager = RecordingPowerAssertionManager(failingKinds: [.networkClientActive])
        let keeper = BackgroundTaskPowerKeeper(
            configuration: PowerKeepAliveConfiguration(isEnabled: true),
            manager: manager
        )

        let status = keeper.start()

        XCTAssertEqual(status.activeAssertions, [
            .preventUserIdleSystemSleep,
            .preventDiskIdle
        ])
        XCTAssertEqual(status.failures, [
            PowerAssertionFailure(kind: .networkClientActive, returnCode: -1)
        ])
    }

    func testSystemPolicyModeActivatesAndRestoresSystemPolicy() {
        let manager = RecordingPowerAssertionManager()
        let systemPolicyManager = RecordingSystemPowerPolicyManager()
        let keeper = BackgroundTaskPowerKeeper(
            configuration: PowerKeepAliveConfiguration(isEnabled: true, systemPolicyMode: .enabled),
            manager: manager,
            systemPolicyManager: systemPolicyManager
        )

        let status = keeper.start()
        keeper.stop()

        XCTAssertEqual(status.systemPolicyStatus, RecordingSystemPowerPolicyManager.activeStatus)
        XCTAssertEqual(systemPolicyManager.actions(), [.activate, .restore])
    }

    func testSystemPolicyModeDoesNotDuplicateActivationWhenStartIsCalledTwice() {
        let systemPolicyManager = RecordingSystemPowerPolicyManager()
        let keeper = BackgroundTaskPowerKeeper(
            configuration: PowerKeepAliveConfiguration(isEnabled: true, systemPolicyMode: .enabled),
            manager: RecordingPowerAssertionManager(),
            systemPolicyManager: systemPolicyManager
        )

        _ = keeper.start()
        let secondStatus = keeper.start()

        XCTAssertNil(secondStatus.systemPolicyStatus)
        XCTAssertEqual(systemPolicyManager.actions(), [.activate])
    }

    func testSnapshotMapsHealthySystemPolicyToVerifiedState() {
        let systemPolicyManager = RecordingSystemPowerPolicyManager()
        let keeper = BackgroundTaskPowerKeeper(
            configuration: PowerKeepAliveConfiguration(isEnabled: true, systemPolicyMode: .enabled),
            manager: RecordingPowerAssertionManager(),
            systemPolicyManager: systemPolicyManager
        )

        let snapshot = keeper.snapshot(from: keeper.start(), checkedAt: Date(timeIntervalSince1970: 10))

        XCTAssertEqual(snapshot.mode, .systemPolicy)
        XCTAssertEqual(snapshot.state, .verified)
        XCTAssertEqual(snapshot.checkedAt, Date(timeIntervalSince1970: 10))
    }

    func testVerifyAndRepairRestartsWhenSystemPolicyDrifts() {
        let systemPolicyManager = RecordingSystemPowerPolicyManager(
            verifyStatus: SystemPowerPolicyStatus(
                isActive: false,
                appliedSettings: [.sleep],
                appliedDisableSleep: true,
                failures: [
                    SystemPowerPolicyFailure(
                        reason: .verificationFailed,
                        arguments: ["-b", "sleep", "0"],
                        output: "observed sleep=1"
                    )
                ]
            )
        )
        let keeper = BackgroundTaskPowerKeeper(
            configuration: PowerKeepAliveConfiguration(isEnabled: true, systemPolicyMode: .enabled),
            manager: RecordingPowerAssertionManager(),
            systemPolicyManager: systemPolicyManager
        )

        _ = keeper.start()
        let snapshot = keeper.verifyAndRepair(checkedAt: Date(timeIntervalSince1970: 20))

        XCTAssertEqual(snapshot.state, .verified)
        XCTAssertEqual(snapshot.checkedAt, Date(timeIntervalSince1970: 20))
        XCTAssertEqual(systemPolicyManager.actions(), [.activate, .verify, .restore, .activate])
    }

    func testVerifyAndRepairDoesNotLoopOnUnrepairableSystemPolicyFailure() {
        let systemPolicyManager = RecordingSystemPowerPolicyManager(
            verifyStatus: SystemPowerPolicyStatus(
                isActive: false,
                appliedSettings: [.sleep],
                appliedDisableSleep: false,
                failures: [
                    SystemPowerPolicyFailure(
                        reason: .applyFailed,
                        arguments: ["-a", "disablesleep", "1"],
                        output: "unsupported"
                    )
                ]
            )
        )
        let keeper = BackgroundTaskPowerKeeper(
            configuration: PowerKeepAliveConfiguration(isEnabled: true, systemPolicyMode: .enabled),
            manager: RecordingPowerAssertionManager(),
            systemPolicyManager: systemPolicyManager
        )

        _ = keeper.start()
        let snapshot = keeper.verifyAndRepair(checkedAt: Date(timeIntervalSince1970: 30))

        XCTAssertEqual(snapshot.state, .degraded)
        XCTAssertEqual(systemPolicyManager.actions(), [.activate, .verify])
    }
}

private final class RecordingPowerAssertionManager: PowerAssertionManaging, @unchecked Sendable {
    private let failingKinds: Set<PowerAssertionKind>
    private let lock = NSLock()
    private var created: [PowerAssertionKind] = []
    private var released: [PowerAssertionKind] = []

    init(failingKinds: Set<PowerAssertionKind> = []) {
        self.failingKinds = failingKinds
    }

    func createAssertion(
        kind: PowerAssertionKind,
        reason: String
    ) -> Result<PowerAssertionHandle, PowerAssertionFailure> {
        lock.lock()
        created.append(kind)
        let rawID = UInt32(created.count)
        lock.unlock()

        if failingKinds.contains(kind) {
            return .failure(PowerAssertionFailure(kind: kind, returnCode: -1))
        }

        return .success(PowerAssertionHandle(kind: kind, rawID: rawID))
    }

    @discardableResult
    func releaseAssertion(_ handle: PowerAssertionHandle) -> Int32 {
        lock.lock()
        released.append(handle.kind)
        lock.unlock()

        return 0
    }

    func createdKinds() -> [PowerAssertionKind] {
        lock.lock()
        defer { lock.unlock() }
        return created
    }

    func releasedKinds() -> [PowerAssertionKind] {
        lock.lock()
        defer { lock.unlock() }
        return released
    }
}

private final class RecordingSystemPowerPolicyManager: SystemPowerPolicyManaging, @unchecked Sendable {
    enum Action: Equatable {
        case activate
        case verify
        case restore
    }

    static let activeStatus = SystemPowerPolicyStatus(
        isActive: true,
        appliedSettings: [.sleep, .disksleep],
        appliedDisableSleep: true,
        failures: []
    )

    private let lock = NSLock()
    private let verifyStatus: SystemPowerPolicyStatus
    private var recordedActions: [Action] = []

    init(verifyStatus: SystemPowerPolicyStatus = activeStatus) {
        self.verifyStatus = verifyStatus
    }

    func activate() -> SystemPowerPolicyStatus {
        lock.lock()
        recordedActions.append(.activate)
        lock.unlock()

        return Self.activeStatus
    }

    func verify() -> SystemPowerPolicyStatus {
        lock.lock()
        recordedActions.append(.verify)
        lock.unlock()

        return verifyStatus
    }

    func restore() -> SystemPowerPolicyStatus {
        lock.lock()
        recordedActions.append(.restore)
        lock.unlock()

        return .inactive
    }

    func actions() -> [Action] {
        lock.lock()
        defer { lock.unlock() }
        return recordedActions
    }
}
