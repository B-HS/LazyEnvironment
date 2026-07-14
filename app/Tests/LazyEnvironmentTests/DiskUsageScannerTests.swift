import Foundation
import Testing
@testable import LazyEnvironment

struct DiskUsageScannerTests {
    @Test
    func measuresAtLeastFileSize() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let oneMebibyte = 1024 * 1024
        let fileURL = directory.appendingPathComponent("payload.bin")
        try Data(count: oneMebibyte).write(to: fileURL)

        let measured = await DiskUsageScanner().measureBytes(atExpandedPath: fileURL.path)
        #expect(measured != nil)
        #expect((measured ?? 0) >= Int64(oneMebibyte))
    }

    @Test
    func returnsNilForNonexistentPath() async {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("missing.bin")
        let measured = await DiskUsageScanner().measureBytes(atExpandedPath: missing.path)
        #expect(measured == nil)
    }
}
