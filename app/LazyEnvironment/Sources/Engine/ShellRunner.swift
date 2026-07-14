import Foundation

enum ShellEvent: Sendable {
    case line(LogLine)
    case exited(Int32)
}

struct CapturedResult: Sendable, Hashable {
    var exitCode: Int32
    var stdout: String
    var stderr: String
}

private final class LineAccumulator: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()

    func append(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)
        var lines: [String] = []
        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = buffer[buffer.startIndex..<newlineIndex]
            lines.append(String(decoding: lineData, as: UTF8.self))
            buffer.removeSubrange(buffer.startIndex...newlineIndex)
        }
        return lines
    }

    func flush() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard !buffer.isEmpty else { return nil }
        let remainder = String(decoding: buffer, as: UTF8.self)
        buffer.removeAll()
        return remainder
    }
}

private final class RunCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var stdoutClosed = false
    private var stderrClosed = false
    private var exitCode: Int32?
    private var finished = false

    func closeStdout() -> Int32? {
        lock.lock()
        defer { lock.unlock() }
        stdoutClosed = true
        return readyExitCodeLocked()
    }

    func closeStderr() -> Int32? {
        lock.lock()
        defer { lock.unlock() }
        stderrClosed = true
        return readyExitCodeLocked()
    }

    func recordExit(_ code: Int32) -> Int32? {
        lock.lock()
        defer { lock.unlock() }
        exitCode = code
        return readyExitCodeLocked()
    }

    private func readyExitCodeLocked() -> Int32? {
        guard stdoutClosed, stderrClosed, let exitCode, !finished else { return nil }
        finished = true
        return exitCode
    }
}

struct ShellRunner: Sendable {
    func events(for command: ResolvedCommand) -> AsyncStream<ShellEvent> {
        AsyncStream { continuation in
            let process = Process()
            if command.runsAsAdmin {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", command.appleScriptSource]
            } else {
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = command.shellArguments
            }
            process.environment = command.environment
            process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.standardInput = FileHandle.nullDevice

            let stdoutAccumulator = LineAccumulator()
            let stderrAccumulator = LineAccumulator()
            let completion = RunCompletion()

            let finishIfReady: @Sendable (Int32?) -> Void = { exitCode in
                guard let exitCode else { return }
                continuation.yield(.exited(exitCode))
                continuation.finish()
            }

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    if let remainder = stdoutAccumulator.flush() {
                        continuation.yield(.line(LogLine(stream: .stdout, text: remainder)))
                    }
                    finishIfReady(completion.closeStdout())
                    return
                }
                for text in stdoutAccumulator.append(data) {
                    continuation.yield(.line(LogLine(stream: .stdout, text: text)))
                }
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    if let remainder = stderrAccumulator.flush() {
                        continuation.yield(.line(LogLine(stream: .stderr, text: remainder)))
                    }
                    finishIfReady(completion.closeStderr())
                    return
                }
                for text in stderrAccumulator.append(data) {
                    continuation.yield(.line(LogLine(stream: .stderr, text: text)))
                }
            }

            process.terminationHandler = { finished in
                finishIfReady(completion.recordExit(finished.terminationStatus))
            }

            continuation.onTermination = { _ in
                if process.isRunning {
                    process.terminate()
                }
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                continuation.yield(.line(LogLine(stream: .system, text: error.localizedDescription)))
                continuation.yield(.exited(-1))
                continuation.finish()
            }
        }
    }

    func capture(_ command: ResolvedCommand) async -> CapturedResult {
        var stdoutLines: [String] = []
        var stderrLines: [String] = []
        var exitCode: Int32 = -1
        for await event in events(for: command) {
            switch event {
            case .line(let line):
                switch line.stream {
                case .stdout: stdoutLines.append(line.text)
                case .stderr, .system: stderrLines.append(line.text)
                }
            case .exited(let code):
                exitCode = code
            }
        }
        return CapturedResult(
            exitCode: exitCode,
            stdout: stdoutLines.joined(separator: "\n"),
            stderr: stderrLines.joined(separator: "\n")
        )
    }
}
