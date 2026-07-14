import Foundation
import Testing
@testable import LazyEnvironment

struct LocalStoreTests {
    private func makeTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    @Test
    func settingsRoundTrip() {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalStore(directoryURL: directory)

        var settings = AppSettings.default
        settings.devHome = "~/work/dev"
        settings.language = .korean
        settings.confirmBeforeEveryRun = true
        store.save(settings: settings)

        #expect(store.loadSettings() == settings)
    }

    @Test
    func stateRoundTripPreservesDiskUsageDates() {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalStore(directoryURL: directory)

        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let finishedAt = Date(timeIntervalSince1970: 1_700_000_042)
        let updatedAt = Date(timeIntervalSince1970: 1_699_999_500)
        let recipeState = RecipePersistedState(
            pinnedVersion: "1.24.0",
            lastDetectedVersion: "1.24.1",
            lastRun: RunRecord(
                action: .install,
                commandDisplay: "zsh -c 'echo hi'",
                startedAt: startedAt,
                finishedAt: finishedAt,
                exitCode: 0,
                logText: "hi\n"
            ),
            hasConfirmedFirstRun: true
        )
        let state = PersistedState(
            recipes: ["go": recipeState],
            diskUsageByPath: ["/dev/go": DiskUsageEntry(bytes: 1_048_576, updatedAt: updatedAt)]
        )
        store.save(state: state)

        let loaded = store.loadState()
        #expect(loaded.recipes["go"] == recipeState)
        #expect(loaded.diskUsageByPath["/dev/go"]?.bytes == 1_048_576)
        #expect(loaded.diskUsageByPath["/dev/go"]?.updatedAt == updatedAt)
    }

    @Test
    func customRecipesRoundTrip() {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalStore(directoryURL: directory)

        let recipes = [
            Recipe(
                id: "my-tool",
                displayName: "My Tool",
                category: .custom,
                installCommand: "echo install",
                envVars: ["FOO": "bar"],
                requiresInteractiveShell: true,
                sourcePinning: .pinned(version: "1.0.0")
            ),
            Recipe(id: "other", displayName: "Other", category: .language),
        ]
        store.save(customRecipes: recipes)

        #expect(store.loadCustomRecipes() == recipes)
    }

    @Test
    func emptyDirectoryReturnsDefaults() {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalStore(directoryURL: directory)

        #expect(store.loadSettings() == .default)
        #expect(store.loadCustomRecipes().isEmpty)
        let state = store.loadState()
        #expect(state.recipes.isEmpty)
        #expect(state.diskUsageByPath.isEmpty)
    }

    @Test
    func corruptedFilesFallBackToDefaults() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalStore(directoryURL: directory)

        for fileName in ["settings.json", "state.json", "custom-recipes.json"] {
            try Data("{ not valid json".utf8).write(to: directory.appendingPathComponent(fileName))
        }

        #expect(store.loadSettings() == .default)
        #expect(store.loadCustomRecipes().isEmpty)
        let state = store.loadState()
        #expect(state.recipes.isEmpty)
        #expect(state.diskUsageByPath.isEmpty)
    }
}
