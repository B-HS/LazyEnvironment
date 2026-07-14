import Foundation

struct DiskUsageScanner: Sendable {
    private static let bytesPerDuBlock: Int64 = 1024

    func measureBytes(atExpandedPath path: String) async -> Int64? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: Self.runDu(path: path))
            }
        }
    }

    private static func runDu(path: String) -> Int64? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(decoding: data, as: UTF8.self)
        guard let firstField = output.split(separator: "\t").first ?? output.split(separator: " ").first,
              let kilobytes = Int64(firstField.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return kilobytes * bytesPerDuBlock
    }
}
