import Foundation
import Testing
@testable import LazyEnvironment

struct CommandResolverTests {
    private let resolver = CommandResolver(versionResolver: LatestVersionResolver())
    private let settings: AppSettings = {
        var settings = AppSettings.default
        settings.devHome = "/opt/dev"
        return settings
    }()

    @Test
    func leavesScriptWithoutTokensUnchanged() async throws {
        let recipe = Recipe(id: "plain", displayName: "Plain", category: .custom)
        let result = try await resolver.resolve(script: "brew install foo", recipe: recipe, settings: settings, pinnedVersion: nil)
        #expect(result.script == "brew install foo")
    }

    @Test
    func nonInteractiveEnvironmentMergesRecipeVars() async throws {
        let recipe = Recipe(
            id: "env",
            displayName: "Env",
            category: .custom,
            envVars: ["TOOLS": "$DEV_HOME/tools", "TERM": "xterm-256color"],
            requiresInteractiveShell: false
        )
        let result = try await resolver.resolve(script: "echo hi", recipe: recipe, settings: settings, pinnedVersion: nil)
        #expect(result.interactive == false)
        #expect(result.environment["PATH"] == CommandResolver.basePath)
        #expect(result.environment["DEV_HOME"] == "/opt/dev")
        #expect(result.environment["TOOLS"] == "/opt/dev/tools")
        #expect(result.environment["TERM"] == "xterm-256color")
        #expect(result.recipeEnvironment["TOOLS"] == "/opt/dev/tools")
        #expect(result.recipeEnvironment["TERM"] == "xterm-256color")
    }

    @Test
    func interactiveRecipeUsesInteractiveShellArguments() async throws {
        let recipe = Recipe(id: "interactive", displayName: "Interactive", category: .custom, requiresInteractiveShell: true)
        let result = try await resolver.resolve(script: "nvm install node", recipe: recipe, settings: settings, pinnedVersion: nil)
        #expect(result.interactive == true)
        #expect(result.shellArguments == ["-ic", "nvm install node"])
    }

    @Test
    func nonInteractiveRecipeUsesNonInteractiveShellArguments() async throws {
        let recipe = Recipe(id: "batch", displayName: "Batch", category: .custom, requiresInteractiveShell: false)
        let result = try await resolver.resolve(script: "brew upgrade", recipe: recipe, settings: settings, pinnedVersion: nil)
        #expect(result.interactive == false)
        #expect(result.shellArguments == ["-c", "brew upgrade"])
    }

    @Test
    func replacesVersionTokenWithPinnedVersion() async throws {
        let recipe = Recipe(id: "pin", displayName: "Pin", category: .custom)
        let result = try await resolver.resolve(script: "install tool@{{version}}", recipe: recipe, settings: settings, pinnedVersion: "1.2.3")
        #expect(result.script == "install tool@1.2.3")
    }

    @Test
    func resolvesLatestTagFromPinnedSource() async throws {
        let recipe = Recipe(id: "latest", displayName: "Latest", category: .custom, sourcePinning: .pinned(version: "9.9.9"))
        let result = try await resolver.resolve(script: "download v{{latestTag}}", recipe: recipe, settings: settings, pinnedVersion: nil)
        #expect(result.script == "download v9.9.9")
    }

    @Test
    func latestTokenWithoutPinningThrows() async {
        let recipe = Recipe(id: "unpinned", displayName: "Unpinned", category: .custom)
        await #expect(throws: CommandResolutionError.self) {
            try await resolver.resolve(script: "get {{latestTag}}", recipe: recipe, settings: settings, pinnedVersion: nil)
        }
    }

    @Test
    func displayStringContainsEnvAssignmentsAndNonInteractiveShell() async throws {
        let recipe = Recipe(
            id: "display",
            displayName: "Display",
            category: .custom,
            envVars: ["ALPHA": "one", "BRAVO": "two"],
            requiresInteractiveShell: false
        )
        let result = try await resolver.resolve(script: "echo hi", recipe: recipe, settings: settings, pinnedVersion: nil)
        #expect(result.displayString.contains("ALPHA=one"))
        #expect(result.displayString.contains("BRAVO=two"))
        #expect(result.displayString.contains("zsh -c"))
    }

    @Test
    func displayStringContainsInteractiveShell() async throws {
        let recipe = Recipe(
            id: "display-interactive",
            displayName: "Display Interactive",
            category: .custom,
            envVars: ["CHARLIE": "three"],
            requiresInteractiveShell: true
        )
        let result = try await resolver.resolve(script: "run task", recipe: recipe, settings: settings, pinnedVersion: nil)
        #expect(result.displayString.contains("CHARLIE=three"))
        #expect(result.displayString.contains("zsh -ic"))
    }
}
