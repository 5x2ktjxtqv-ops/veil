import Darwin
import Foundation

enum SystemPowerPolicySetting: String, CaseIterable, Equatable, Sendable {
    case sleep
    case disksleep
    case standby
    case autopoweroff
    case lowpowermode
    case tcpkeepalive
    case ttyskeepawake
    case powernap
    case womp

    var systemModeValue: String {
        switch self {
        case .sleep, .disksleep, .standby, .autopoweroff, .lowpowermode:
            return "0"
        case .tcpkeepalive, .ttyskeepawake, .powernap, .womp:
            return "1"
        }
    }
}

enum PowerSourceScope: String, CaseIterable, Equatable, Sendable {
    case battery
    case charger
    case ups

    var pmsetFlag: String {
        switch self {
        case .battery:
            return "-b"
        case .charger:
            return "-c"
        case .ups:
            return "-u"
        }
    }
}

struct SystemPowerPolicySnapshot: Equatable, Sendable {
    var values: [PowerSourceScope: [SystemPowerPolicySetting: String]]

    static let empty = SystemPowerPolicySnapshot(values: [:])
}

enum SystemPowerPolicyFailureReason: Equatable, Sendable {
    case requiresRoot
    case snapshotUnavailable
    case applyFailed
    case verificationFailed
    case restoreFailed
}

struct SystemPowerPolicyFailure: Equatable, Sendable {
    var reason: SystemPowerPolicyFailureReason
    var arguments: [String]
    var output: String
}

struct SystemPowerPolicyStatus: Equatable, Sendable {
    var isActive: Bool
    var appliedSettings: [SystemPowerPolicySetting]
    var appliedDisableSleep: Bool
    var failures: [SystemPowerPolicyFailure]

    static let inactive = SystemPowerPolicyStatus(
        isActive: false,
        appliedSettings: [],
        appliedDisableSleep: false,
        failures: []
    )
}

protocol RootPrivilegeChecking: Sendable {
    var isRunningAsRoot: Bool { get }
}

struct SystemRootPrivilegeChecker: RootPrivilegeChecking {
    var isRunningAsRoot: Bool {
        geteuid() == 0
    }
}

protocol SystemPowerPolicyManaging: Sendable {
    func activate() -> SystemPowerPolicyStatus
    func verify() -> SystemPowerPolicyStatus
    func restore() -> SystemPowerPolicyStatus
}

final class PMSetSystemPowerPolicyManager: SystemPowerPolicyManaging, @unchecked Sendable {
    private let processRunner: any ProcessRunning
    private let rootPrivilegeChecker: any RootPrivilegeChecking
    private let lock = NSLock()
    private var snapshot: SystemPowerPolicySnapshot?
    private var disableSleepWasApplied = false

    init(
        processRunner: any ProcessRunning = ProcessRunner(),
        rootPrivilegeChecker: any RootPrivilegeChecking = SystemRootPrivilegeChecker()
    ) {
        self.processRunner = processRunner
        self.rootPrivilegeChecker = rootPrivilegeChecker
    }

    func activate() -> SystemPowerPolicyStatus {
        guard rootPrivilegeChecker.isRunningAsRoot else {
            return SystemPowerPolicyStatus(
                isActive: false,
                appliedSettings: [],
                appliedDisableSleep: false,
                failures: [
                    SystemPowerPolicyFailure(
                        reason: .requiresRoot,
                        arguments: [],
                        output: "System power keepalive requires root. Launch Veil with sudo to allow pmset changes."
                    )
                ]
            )
        }

        let capturedSnapshot: SystemPowerPolicySnapshot
        do {
            capturedSnapshot = try captureSnapshot()
        } catch {
            return SystemPowerPolicyStatus(
                isActive: false,
                appliedSettings: [],
                appliedDisableSleep: false,
                failures: [
                    SystemPowerPolicyFailure(
                        reason: .snapshotUnavailable,
                        arguments: ["-g", "custom"],
                        output: "\(error)"
                    )
                ]
            )
        }

        lock.lock()
        if snapshot == nil {
            snapshot = capturedSnapshot
        }
        lock.unlock()

        let supportedSettings = supportedPolicySettings()
        let settingsArguments = pmsetArguments(for: supportedSettings)
        var failures: [SystemPowerPolicyFailure] = []

        if !settingsArguments.isEmpty {
            let result = processRunner.runResult(
                "/usr/bin/pmset",
                arguments: ["-a"] + settingsArguments,
                timeout: 4
            )
            if result.termination != .exited(0) {
                failures.append(SystemPowerPolicyFailure(
                    reason: .applyFailed,
                    arguments: ["-a"] + settingsArguments,
                    output: result.output
                ))
            }
        }

        let disableSleepResult = processRunner.runResult(
            "/usr/bin/pmset",
            arguments: ["-a", "disablesleep", "1"],
            timeout: 4
        )
        let appliedDisableSleep = disableSleepResult.termination == .exited(0)
        if appliedDisableSleep {
            lock.lock()
            disableSleepWasApplied = true
            lock.unlock()
        } else {
            failures.append(SystemPowerPolicyFailure(
                reason: .applyFailed,
                arguments: ["-a", "disablesleep", "1"],
                output: disableSleepResult.output
            ))
        }

        return SystemPowerPolicyStatus(
            isActive: failures.isEmpty,
            appliedSettings: supportedSettings,
            appliedDisableSleep: appliedDisableSleep,
            failures: failures
        )
    }

    func restore() -> SystemPowerPolicyStatus {
        guard rootPrivilegeChecker.isRunningAsRoot else {
            return SystemPowerPolicyStatus(
                isActive: false,
                appliedSettings: [],
                appliedDisableSleep: false,
                failures: [
                    SystemPowerPolicyFailure(
                        reason: .requiresRoot,
                        arguments: [],
                        output: "System power keepalive restore requires root."
                    )
                ]
            )
        }

        lock.lock()
        let snapshot = self.snapshot
        let shouldRestoreDisableSleep = disableSleepWasApplied
        self.snapshot = nil
        disableSleepWasApplied = false
        lock.unlock()

        var failures: [SystemPowerPolicyFailure] = []

        if let snapshot {
            failures.append(contentsOf: restore(snapshot: snapshot))
        }

        if shouldRestoreDisableSleep {
            let result = processRunner.runResult(
                "/usr/bin/pmset",
                arguments: ["-a", "disablesleep", "0"],
                timeout: 4
            )
            if result.termination != .exited(0) {
                failures.append(SystemPowerPolicyFailure(
                    reason: .restoreFailed,
                    arguments: ["-a", "disablesleep", "0"],
                    output: result.output
                ))
            }
        }

        return SystemPowerPolicyStatus(
            isActive: false,
            appliedSettings: [],
            appliedDisableSleep: false,
            failures: failures
        )
    }

    func verify() -> SystemPowerPolicyStatus {
        guard rootPrivilegeChecker.isRunningAsRoot else {
            return SystemPowerPolicyStatus(
                isActive: false,
                appliedSettings: [],
                appliedDisableSleep: false,
                failures: [
                    SystemPowerPolicyFailure(
                        reason: .requiresRoot,
                        arguments: [],
                        output: "System power keepalive verification requires root."
                    )
                ]
            )
        }

        let supportedSettings = supportedPolicySettings()
        let snapshot: SystemPowerPolicySnapshot
        do {
            snapshot = try captureSnapshot()
        } catch {
            return SystemPowerPolicyStatus(
                isActive: false,
                appliedSettings: [],
                appliedDisableSleep: false,
                failures: [
                    SystemPowerPolicyFailure(
                        reason: .snapshotUnavailable,
                        arguments: ["-g", "custom"],
                        output: "\(error)"
                    )
                ]
            )
        }

        var failures: [SystemPowerPolicyFailure] = []
        for source in PowerSourceScope.allCases {
            guard let sourceValues = snapshot.values[source], !sourceValues.isEmpty else { continue }

            for setting in supportedSettings {
                guard let value = sourceValues[setting] else { continue }
                guard value == setting.systemModeValue else {
                    failures.append(SystemPowerPolicyFailure(
                        reason: .verificationFailed,
                        arguments: [source.pmsetFlag, setting.rawValue, setting.systemModeValue],
                        output: "observed \(setting.rawValue)=\(value)"
                    ))
                    continue
                }
            }
        }

        lock.lock()
        let appliedDisableSleep = disableSleepWasApplied
        lock.unlock()

        return SystemPowerPolicyStatus(
            isActive: failures.isEmpty && appliedDisableSleep,
            appliedSettings: supportedSettings,
            appliedDisableSleep: appliedDisableSleep,
            failures: failures
        )
    }

    private func captureSnapshot() throws -> SystemPowerPolicySnapshot {
        let result = processRunner.runResult("/usr/bin/pmset", arguments: ["-g", "custom"], timeout: 4)
        guard result.termination == .exited(0) else {
            throw PMSetSystemPowerPolicyError.commandFailed(result.output)
        }

        return Self.parseCustomSettings(result.output)
    }

    private func supportedPolicySettings() -> [SystemPowerPolicySetting] {
        let result = processRunner.runResult("/usr/bin/pmset", arguments: ["-g", "cap"], timeout: 4)
        guard result.termination == .exited(0) else {
            return [.sleep, .disksleep, .tcpkeepalive, .ttyskeepawake]
        }

        let supported = Self.parseCapabilities(result.output)
        return SystemPowerPolicySetting.allCases.filter { supported.contains($0.rawValue) }
    }

    private func pmsetArguments(for settings: [SystemPowerPolicySetting]) -> [String] {
        settings.flatMap { [$0.rawValue, $0.systemModeValue] }
    }

    private func restore(snapshot: SystemPowerPolicySnapshot) -> [SystemPowerPolicyFailure] {
        var failures: [SystemPowerPolicyFailure] = []

        for source in PowerSourceScope.allCases {
            guard let values = snapshot.values[source], !values.isEmpty else { continue }

            let arguments = [source.pmsetFlag] + SystemPowerPolicySetting.allCases.flatMap { setting -> [String] in
                guard let value = values[setting] else { return [] }
                return [setting.rawValue, value]
            }

            guard arguments.count > 1 else { continue }

            let result = processRunner.runResult("/usr/bin/pmset", arguments: arguments, timeout: 4)
            if result.termination != .exited(0) {
                failures.append(SystemPowerPolicyFailure(
                    reason: .restoreFailed,
                    arguments: arguments,
                    output: result.output
                ))
            }
        }

        return failures
    }

    static func parseCapabilities(_ output: String) -> Set<String> {
        Set(output
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.hasSuffix(":") })
    }

    static func parseCustomSettings(_ output: String) -> SystemPowerPolicySnapshot {
        var values: [PowerSourceScope: [SystemPowerPolicySetting: String]] = [:]
        var currentScope: PowerSourceScope?

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            switch line {
            case "Battery Power:":
                currentScope = .battery
                continue
            case "AC Power:":
                currentScope = .charger
                continue
            case "UPS Power:":
                currentScope = .ups
                continue
            default:
                break
            }

            guard let currentScope else { continue }
            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 2,
                  let setting = SystemPowerPolicySetting(rawValue: String(parts[0])) else {
                continue
            }

            values[currentScope, default: [:]][setting] = String(parts[1])
        }

        return SystemPowerPolicySnapshot(values: values)
    }
}

private enum PMSetSystemPowerPolicyError: Error, Equatable {
    case commandFailed(String)
}
