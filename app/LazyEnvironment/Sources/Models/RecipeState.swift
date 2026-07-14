import Foundation

enum RecipeAction: String, Codable, Sendable {
    case install
    case update
    case uninstall
}

enum RecipeStatus: Hashable, Sendable {
    case unknown
    case notInstalled
    case installed(version: String?)
    case installedExternally(version: String?)
    case broken(message: String)
}

enum LogStream: String, Codable, Sendable {
    case stdout
    case stderr
    case system
}

struct LogLine: Identifiable, Hashable, Sendable {
    let id: UUID
    let stream: LogStream
    let text: String
    let timestamp: Date

    init(stream: LogStream, text: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.stream = stream
        self.text = text
        self.timestamp = timestamp
    }
}

struct RunRecord: Codable, Hashable, Sendable {
    var action: RecipeAction
    var commandDisplay: String
    var startedAt: Date
    var finishedAt: Date?
    var exitCode: Int32?
    var logText: String
}

struct DiskUsageEntry: Codable, Hashable, Sendable {
    var bytes: Int64
    var updatedAt: Date
}

struct RecipePersistedState: Codable, Hashable, Sendable {
    var pinnedVersion: String?
    var lastDetectedVersion: String?
    var lastRun: RunRecord?
    var hasConfirmedFirstRun: Bool
    var customDevHome: String?

    init(
        pinnedVersion: String? = nil,
        lastDetectedVersion: String? = nil,
        lastRun: RunRecord? = nil,
        hasConfirmedFirstRun: Bool = false,
        customDevHome: String? = nil
    ) {
        self.pinnedVersion = pinnedVersion
        self.lastDetectedVersion = lastDetectedVersion
        self.lastRun = lastRun
        self.hasConfirmedFirstRun = hasConfirmedFirstRun
        self.customDevHome = customDevHome
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pinnedVersion = try container.decodeIfPresent(String.self, forKey: .pinnedVersion)
        lastDetectedVersion = try container.decodeIfPresent(String.self, forKey: .lastDetectedVersion)
        lastRun = try container.decodeIfPresent(RunRecord.self, forKey: .lastRun)
        hasConfirmedFirstRun = try container.decodeIfPresent(Bool.self, forKey: .hasConfirmedFirstRun) ?? false
        customDevHome = try container.decodeIfPresent(String.self, forKey: .customDevHome)
    }
}

struct PersistedState: Codable, Sendable {
    var recipes: [String: RecipePersistedState]
    var diskUsageByPath: [String: DiskUsageEntry]
    var lastSyncedAt: Date?

    static let empty = PersistedState(recipes: [:], diskUsageByPath: [:])

    init(recipes: [String: RecipePersistedState], diskUsageByPath: [String: DiskUsageEntry], lastSyncedAt: Date? = nil) {
        self.recipes = recipes
        self.diskUsageByPath = diskUsageByPath
        self.lastSyncedAt = lastSyncedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recipes = try container.decodeIfPresent([String: RecipePersistedState].self, forKey: .recipes) ?? [:]
        diskUsageByPath = try container.decodeIfPresent([String: DiskUsageEntry].self, forKey: .diskUsageByPath) ?? [:]
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
    }
}
