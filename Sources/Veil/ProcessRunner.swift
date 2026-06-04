import Darwin
import Foundation

struct ProcessRunResult: Equatable, Sendable {
    enum Termination: Equatable, Sendable {
        case exited(Int32)
        case failedToStart
        case timedOut
    }

    var standardOutput: String
    var standardError: String
    var termination: Termination

    var output: String {
        [standardOutput, standardError]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    var legacyOutput: String? {
        guard termination != .failedToStart, termination != .timedOut else { return nil }
        let trimmed = output
        return trimmed.isEmpty ? nil : trimmed
    }
}

protocol ProcessRunning: Sendable {
    func run(_ executable: String, arguments: [String], timeout: TimeInterval) -> String?
    func runResult(_ executable: String, arguments: [String], timeout: TimeInterval) -> ProcessRunResult
}

extension ProcessRunning {
    func run(_ executable: String, arguments: [String], timeout: TimeInterval) -> String? {
        runResult(executable, arguments: arguments, timeout: timeout).legacyOutput
    }

    func runResult(_ executable: String, arguments: [String], timeout: TimeInterval) -> ProcessRunResult {
        if let output = run(executable, arguments: arguments, timeout: timeout) {
            return ProcessRunResult(
                standardOutput: output,
                standardError: "",
                termination: .exited(0)
            )
        }

        return ProcessRunResult(
            standardOutput: "",
            standardError: "",
            termination: .failedToStart
        )
    }
}

struct ProcessRunner: ProcessRunning {
    func runResult(_ executable: String, arguments: [String], timeout: TimeInterval) -> ProcessRunResult {
        Self.runResult(executable, arguments: arguments, timeout: timeout)
    }

    static func runResult(_ executable: String, arguments: [String], timeout: TimeInterval) -> ProcessRunResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let outputBuffer = LockedDataBuffer()
        let errorBuffer = LockedDataBuffer()
        let readerGroup = DispatchGroup()
        startReading(outputPipe.fileHandleForReading, into: outputBuffer, group: readerGroup)
        startReading(errorPipe.fileHandleForReading, into: errorBuffer, group: readerGroup)

        let group = DispatchGroup()
        group.enter()
        process.terminationHandler = { _ in
            group.leave()
        }

        do {
            try process.run()
        } catch {
            closeReadingHandles(outputPipe, errorPipe)
            _ = readerGroup.wait(timeout: .now() + 0.2)
            return ProcessRunResult(
                standardOutput: "",
                standardError: "",
                termination: .failedToStart
            )
        }

        let waitResult = group.wait(timeout: .now() + timeout)
        let termination: ProcessRunResult.Termination
        if waitResult == .timedOut {
            process.terminate()
            if group.wait(timeout: .now() + 0.5) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = group.wait(timeout: .now() + 0.5)
            }
            termination = .timedOut
        } else {
            termination = .exited(process.terminationStatus)
        }

        if readerGroup.wait(timeout: .now() + 0.5) == .timedOut {
            closeReadingHandles(outputPipe, errorPipe)
            _ = readerGroup.wait(timeout: .now() + 0.2)
        }

        return ProcessRunResult(
            standardOutput: outputBuffer.stringValue,
            standardError: errorBuffer.stringValue,
            termination: termination
        )
    }

    private static func startReading(
        _ fileHandle: FileHandle,
        into buffer: LockedDataBuffer,
        group: DispatchGroup
    ) {
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            buffer.append(fileHandle.readDataToEndOfFile())
            group.leave()
        }
    }

    private static func closeReadingHandles(_ outputPipe: Pipe, _ errorPipe: Pipe) {
        try? outputPipe.fileHandleForReading.close()
        try? errorPipe.fileHandleForReading.close()
    }
}

private final class LockedDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    var stringValue: String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        return String(data: snapshot, encoding: .utf8) ?? ""
    }

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }

        lock.lock()
        data.append(chunk)
        lock.unlock()
    }
}
