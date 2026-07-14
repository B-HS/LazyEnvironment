import Foundation
import os

struct LocalStore: Sendable {
    private static let logger = Logger(subsystem: "com.hyunseokbyun.LazyEnvironment", category: "LocalStore")

    let directoryURL: URL

    private var settingsURL: URL { directoryURL.appendingPathComponent("settings.json") }
    private var stateURL: URL { directoryURL.appendingPathComponent("state.json") }
    private var customRecipesURL: URL { directoryURL.appendingPathComponent("custom-recipes.json") }

    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("LazyEnvironment", isDirectory: true)
    }

    init(directoryURL: URL = LocalStore.defaultDirectory()) {
        self.directoryURL = directoryURL
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func loadSettings() -> AppSettings {
        load(from: settingsURL) ?? .default
    }

    func save(settings: AppSettings) {
        save(settings, to: settingsURL)
    }

    func loadState() -> PersistedState {
        load(from: stateURL) ?? .empty
    }

    func save(state: PersistedState) {
        save(state, to: stateURL)
    }

    func loadCustomRecipes() -> [Recipe] {
        load(from: customRecipesURL) ?? []
    }

    func save(customRecipes: [Recipe]) {
        save(customRecipes, to: customRecipesURL)
    }

    private func load<T: Decodable>(from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            Self.logger.error("Failed to decode \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            Self.logger.error("Failed to save \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
