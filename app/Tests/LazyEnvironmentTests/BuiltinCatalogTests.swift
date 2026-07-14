import Foundation
import Testing
@testable import LazyEnvironment

struct BuiltinCatalogTests {
    private let versionTokens = ["{{latestTag}}", "{{latestVersion}}", "{{version}}"]

    private func canResolveVersion(_ pinning: SourcePinning?) -> Bool {
        switch pinning {
        case .githubLatestTag, .goDevJSON, .pinned:
            true
        case .stableURL, .none:
            false
        }
    }

    @Test
    func loadsNonEmptyCatalog() {
        #expect(BuiltinCatalog.load().isEmpty == false)
    }

    @Test
    func recipeIdentifiersAreUnique() {
        let ids = BuiltinCatalog.load().map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test
    func versionTokenRecipesHaveResolvablePinning() {
        for recipe in BuiltinCatalog.load() {
            let script = (recipe.installCommand ?? "") + " " + (recipe.updateCommand ?? "")
            let usesVersionToken = versionTokens.contains { script.contains($0) }
            if usesVersionToken {
                #expect(canResolveVersion(recipe.sourcePinning), "\(recipe.id) uses a version token but has no pinning that can resolve a version")
            }
        }
    }

    @Test
    func interactiveRecipesSourceAProfile() {
        for recipe in BuiltinCatalog.load() where recipe.requiresInteractiveShell {
            let commands = [
                recipe.detectCommand,
                recipe.currentVersionCommand,
                recipe.installCommand,
                recipe.updateCommand,
                recipe.uninstallCommand,
            ].compactMap { $0 }
            #expect(commands.contains { $0.contains("source ") }, "\(recipe.id) requires an interactive shell but no command sources a profile")
        }
    }
}
