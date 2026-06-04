import Darwin
import Foundation

enum PrivilegedRelaunchResult: Equatable {
    case notNeeded
    case launched
    case failed(ProcessRunResult)
}

struct PrivilegedRelauncher {
    static let elevationAttemptedEnvironmentKey = "VEIL_ELEVATION_ATTEMPTED"
    static let systemPowerKeepAliveEnvironmentKey = "VEIL_SYSTEM_POWER_KEEPALIVE"

    var processRunner: any ProcessRunning
    var rootPrivilegeChecker: any RootPrivilegeChecking
    var environment: [String: String]
    var arguments: [String]

    init(
        processRunner: any ProcessRunning = ProcessRunner(),
        rootPrivilegeChecker: any RootPrivilegeChecking = SystemRootPrivilegeChecker(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.processRunner = processRunner
        self.rootPrivilegeChecker = rootPrivilegeChecker
        self.environment = environment
        self.arguments = arguments
    }

    func relaunchIfNeeded(for configuration: RuntimeConfiguration) -> PrivilegedRelaunchResult {
        guard configuration.powerKeepAlive.systemPolicyMode == .enabled else {
            return .notNeeded
        }

        guard !rootPrivilegeChecker.isRunningAsRoot else {
            return .notNeeded
        }

        guard !RuntimeConfiguration.booleanValue(
            environment[Self.elevationAttemptedEnvironmentKey],
            default: false
        ) else {
            return .notNeeded
        }

        guard let executablePath = arguments.first, !executablePath.isEmpty else {
            return .failed(ProcessRunResult(
                standardOutput: "",
                standardError: "Unable to resolve Veil executable path for privileged relaunch.",
                termination: .failedToStart
            ))
        }

        let script = Self.appleScript(for: elevatedShellCommand(executablePath: executablePath))
        let result = processRunner.runResult(
            "/usr/bin/osascript",
            arguments: ["-e", script],
            timeout: 120
        )

        return result.termination == .exited(0) ? .launched : .failed(result)
    }

    private func elevatedShellCommand(executablePath: String) -> String {
        let environmentAssignments = [
            "\(Self.elevationAttemptedEnvironmentKey)=1",
            "\(Self.systemPowerKeepAliveEnvironmentKey)=1"
        ]

        let commandParts = [
            "/usr/bin/env"
        ] + environmentAssignments + [executablePath] + elevatedArguments

        return "trap '' HUP; "
            + commandParts
            .map(Self.shellQuoted)
            .joined(separator: " ")
            + " >/dev/null 2>&1 < /dev/null &"
    }

    private var elevatedArguments: [String] {
        var resolved = Array(arguments.dropFirst())
        if !resolved.contains("--system-power-keepalive") {
            resolved.append("--system-power-keepalive")
        }
        return resolved
    }

    static func appleScript(for shellCommand: String) -> String {
        "do shell script \(appleScriptStringLiteral(shellCommand)) with administrator privileges with prompt \(appleScriptStringLiteral("Veil needs administrator privileges to enable system power keep-alive for background model tasks."))"
    }

    static func appleScriptStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
