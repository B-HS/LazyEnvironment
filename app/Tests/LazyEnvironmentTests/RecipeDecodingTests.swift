import Foundation
import Testing
@testable import LazyEnvironment

struct RecipeDecodingTests {
    @Test
    func decodesMinimalRecipe() throws {
        let json = """
        { "id": "demo", "displayName": "Demo", "category": "custom" }
        """
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        #expect(recipe.id == "demo")
        #expect(recipe.envVars.isEmpty)
        #expect(recipe.diskUsagePaths.isEmpty)
        #expect(recipe.requiresInteractiveShell == false)
        #expect(recipe.sourcePinning == nil)
    }

    @Test
    func decodesSourcePinningVariants() throws {
        let json = """
        [
          { "id": "a", "displayName": "A", "category": "language",
            "sourcePinning": { "type": "github-latest-tag", "repo": "nvm-sh/nvm" } },
          { "id": "b", "displayName": "B", "category": "language",
            "sourcePinning": { "type": "stable-url", "url": "https://sh.rustup.rs" } },
          { "id": "c", "displayName": "C", "category": "language",
            "sourcePinning": { "type": "pinned", "version": "1.2.3" } },
          { "id": "d", "displayName": "D", "category": "language",
            "sourcePinning": { "type": "go-dev-json" } }
        ]
        """
        let recipes = try JSONDecoder().decode([Recipe].self, from: Data(json.utf8))
        #expect(recipes[0].sourcePinning == .githubLatestTag(repo: "nvm-sh/nvm"))
        #expect(recipes[1].sourcePinning == .stableURL(url: "https://sh.rustup.rs"))
        #expect(recipes[2].sourcePinning == .pinned(version: "1.2.3"))
        #expect(recipes[3].sourcePinning == .goDevJSON)
    }

    @Test
    func recipeRoundTripsThroughJSON() throws {
        let recipe = Recipe(
            id: "round-trip",
            displayName: "Round Trip",
            category: .aiAgent,
            envVars: ["FOO": "$DEV_HOME/foo"],
            diskUsagePaths: ["$DEV_HOME/foo"],
            requiresInteractiveShell: true,
            sourcePinning: .githubLatestTag(repo: "octo/repo")
        )
        let data = try JSONEncoder().encode(recipe)
        let decoded = try JSONDecoder().decode(Recipe.self, from: data)
        #expect(decoded == recipe)
    }
}
