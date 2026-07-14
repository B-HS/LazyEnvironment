import Foundation

struct DetectionResult: Sendable, Hashable {
    var isInstalled: Bool
    var version: String?
    var externalCandidateIndex: Int?

    static let notInstalled = DetectionResult(isInstalled: false, version: nil, externalCandidateIndex: nil)
}

struct RecipeEngine: Sendable {
    private enum ProbeResult {
        case notFound
        case found(version: String?)
    }

    let runner: ShellRunner
    let resolver: CommandResolver

    init(runner: ShellRunner = ShellRunner(), resolver: CommandResolver) {
        self.runner = runner
        self.resolver = resolver
    }

    func script(for action: RecipeAction, recipe: Recipe, externalCandidate: ExternalInstallCandidate? = nil) -> String? {
        switch action {
        case .install: recipe.installCommand
        case .update: recipe.updateCommand
        case .uninstall: externalCandidate.map(\.uninstallCommand) ?? recipe.uninstallCommand
        }
    }

    func requiresAdmin(for action: RecipeAction, recipe: Recipe, externalCandidate: ExternalInstallCandidate? = nil) -> Bool {
        if action == .uninstall, let externalCandidate {
            return externalCandidate.uninstallRequiresAdmin
        }
        return recipe.adminActions.contains(action)
    }

    func resolvedCommand(
        for action: RecipeAction,
        recipe: Recipe,
        settings: AppSettings,
        pinnedVersion: String?,
        externalCandidate: ExternalInstallCandidate? = nil
    ) async throws -> ResolvedCommand? {
        guard let script = script(for: action, recipe: recipe, externalCandidate: externalCandidate) else { return nil }
        return try await resolver.resolve(
            script: script,
            recipe: recipe,
            settings: settings,
            pinnedVersion: pinnedVersion,
            runAsAdmin: requiresAdmin(for: action, recipe: recipe, externalCandidate: externalCandidate)
        )
    }

    func detect(recipe: Recipe, settings: AppSettings) async -> DetectionResult {
        if case .found(let version) = await probe(
            detectScript: recipe.detectCommand,
            versionScript: recipe.currentVersionCommand,
            recipe: recipe,
            settings: settings
        ) {
            return DetectionResult(isInstalled: true, version: version, externalCandidateIndex: nil)
        }

        for (index, candidate) in recipe.externalCandidates.enumerated() {
            if case .found(let version) = await probe(
                detectScript: candidate.detectCommand,
                versionScript: candidate.currentVersionCommand,
                recipe: recipe,
                settings: settings
            ) {
                return DetectionResult(isInstalled: true, version: version, externalCandidateIndex: index)
            }
        }

        return .notInstalled
    }

    private func probe(
        detectScript: String?,
        versionScript: String?,
        recipe: Recipe,
        settings: AppSettings
    ) async -> ProbeResult {
        guard let detectScript,
              let detectCommand = try? await resolver.resolve(
                  script: detectScript,
                  recipe: recipe,
                  settings: settings,
                  pinnedVersion: nil
              ) else {
            return .notFound
        }
        let detection = await runner.capture(detectCommand)
        guard detection.exitCode == 0 else {
            return .notFound
        }

        guard let versionScript,
              let versionCommand = try? await resolver.resolve(
                  script: versionScript,
                  recipe: recipe,
                  settings: settings,
                  pinnedVersion: nil
              ) else {
            return .found(version: nil)
        }
        let versionResult = await runner.capture(versionCommand)
        guard versionResult.exitCode == 0 else {
            return .found(version: nil)
        }
        let lines = versionResult.stdout
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return .found(version: recipe.requiresInteractiveShell ? lines.last : lines.first)
    }
}
