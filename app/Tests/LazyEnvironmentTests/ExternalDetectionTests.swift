import Foundation
import Testing
@testable import LazyEnvironment

struct ExternalDetectionTests {
    private let engine = RecipeEngine(resolver: CommandResolver(versionResolver: LatestVersionResolver()))
    private let settings = AppSettings.default

    @Test
    func managedInstallWinsOverCandidates() async {
        let recipe = Recipe(
            id: "managed-first",
            displayName: "Managed First",
            category: .custom,
            detectCommand: "true",
            currentVersionCommand: "echo v1.0.0",
            externalCandidates: [
                ExternalInstallCandidate(label: "fallback", detectCommand: "true", currentVersionCommand: "echo external")
            ]
        )
        let result = await engine.detect(recipe: recipe, settings: settings)
        #expect(result.isInstalled)
        #expect(result.externalCandidateIndex == nil)
        #expect(result.version == "v1.0.0")
    }

    @Test
    func fallsBackToFirstMatchingCandidate() async {
        let recipe = Recipe(
            id: "external-fallback",
            displayName: "External Fallback",
            category: .custom,
            detectCommand: "false",
            externalCandidates: [
                ExternalInstallCandidate(label: "missing", detectCommand: "false"),
                ExternalInstallCandidate(label: "present", detectCommand: "true", currentVersionCommand: "echo v2.3.4"),
            ]
        )
        let result = await engine.detect(recipe: recipe, settings: settings)
        #expect(result.isInstalled)
        #expect(result.externalCandidateIndex == 1)
        #expect(result.version == "v2.3.4")
    }

    @Test
    func reportsNotInstalledWhenNothingMatches() async {
        let recipe = Recipe(
            id: "nothing",
            displayName: "Nothing",
            category: .custom,
            detectCommand: "false",
            externalCandidates: [
                ExternalInstallCandidate(label: "missing", detectCommand: "false")
            ]
        )
        let result = await engine.detect(recipe: recipe, settings: settings)
        #expect(result.isInstalled == false)
        #expect(result.externalCandidateIndex == nil)
    }

    @Test
    func candidateWithoutVersionCommandReportsNilVersion() async {
        let recipe = Recipe(
            id: "no-version",
            displayName: "No Version",
            category: .custom,
            detectCommand: "false",
            externalCandidates: [
                ExternalInstallCandidate(label: "present", detectCommand: "true")
            ]
        )
        let result = await engine.detect(recipe: recipe, settings: settings)
        #expect(result.isInstalled)
        #expect(result.externalCandidateIndex == 0)
        #expect(result.version == nil)
    }

    @Test
    func uninstallRoutesToCandidateWhenExternal() {
        let recipe = Recipe(
            id: "route",
            displayName: "Route",
            category: .custom,
            uninstallCommand: "rm -rf managed"
        )
        let candidateWithUninstall = ExternalInstallCandidate(label: "a", detectCommand: "true", uninstallCommand: "rm -rf external")
        let candidateWithoutUninstall = ExternalInstallCandidate(label: "b", detectCommand: "true")

        #expect(engine.script(for: .uninstall, recipe: recipe, externalCandidate: candidateWithUninstall) == "rm -rf external")
        #expect(engine.script(for: .uninstall, recipe: recipe, externalCandidate: candidateWithoutUninstall) == nil)
        #expect(engine.script(for: .uninstall, recipe: recipe, externalCandidate: nil) == "rm -rf managed")
    }

    @Test
    func resolverHonorsOverriddenDevHome() async throws {
        var overridden = AppSettings.default
        overridden.devHome = "/tmp/custom-base"
        let recipe = Recipe(
            id: "custom-home",
            displayName: "Custom Home",
            category: .custom,
            envVars: ["TOOL_HOME": "$DEV_HOME/tool"]
        )
        let resolved = try await CommandResolver(versionResolver: LatestVersionResolver()).resolve(
            script: "echo hi",
            recipe: recipe,
            settings: overridden,
            pinnedVersion: nil
        )
        #expect(resolved.environment["DEV_HOME"] == "/tmp/custom-base")
        #expect(resolved.environment["TOOL_HOME"] == "/tmp/custom-base/tool")
    }

    @Test
    func adminFlagRoutesFromRecipeAndCandidate() {
        let recipe = Recipe(
            id: "admin",
            displayName: "Admin",
            category: .custom,
            uninstallCommand: "rm -rf managed",
            adminActions: [.install]
        )
        let adminCandidate = ExternalInstallCandidate(label: "a", detectCommand: "true", uninstallCommand: "rm -rf /usr/local/x", uninstallRequiresAdmin: true)
        let plainCandidate = ExternalInstallCandidate(label: "b", detectCommand: "true", uninstallCommand: "rm -rf x")

        #expect(engine.requiresAdmin(for: .install, recipe: recipe))
        #expect(engine.requiresAdmin(for: .update, recipe: recipe) == false)
        #expect(engine.requiresAdmin(for: .uninstall, recipe: recipe) == false)
        #expect(engine.requiresAdmin(for: .uninstall, recipe: recipe, externalCandidate: adminCandidate))
        #expect(engine.requiresAdmin(for: .uninstall, recipe: recipe, externalCandidate: plainCandidate) == false)
    }

    @Test
    func adminResolutionExpandsHomeTokensAndWrapsAppleScript() async throws {
        let recipe = Recipe(
            id: "admin-resolve",
            displayName: "Admin Resolve",
            category: .custom,
            uninstallCommand: "rm -rf \"$HOME/some dir\" /usr/local/x",
            adminActions: [.uninstall]
        )
        let resolved = try await engine.resolvedCommand(
            for: .uninstall,
            recipe: recipe,
            settings: settings,
            pinnedVersion: nil
        )
        let command = try #require(resolved)
        #expect(command.runsAsAdmin)
        #expect(command.script.contains(NSHomeDirectory()))
        #expect(command.script.contains("$HOME") == false)
        #expect(command.appleScriptSource.hasPrefix("do shell script \""))
        #expect(command.appleScriptSource.hasSuffix("\" with administrator privileges"))
        #expect(command.appleScriptSource.contains("\\\"\(NSHomeDirectory())/some dir\\\""))
    }

    @Test
    func externalCandidateDecodesWithDefaults() throws {
        let json = """
        { "label": "default", "detectCommand": "true" }
        """
        let candidate = try JSONDecoder().decode(ExternalInstallCandidate.self, from: Data(json.utf8))
        #expect(candidate.currentVersionCommand == nil)
        #expect(candidate.diskUsagePaths.isEmpty)
    }
}
