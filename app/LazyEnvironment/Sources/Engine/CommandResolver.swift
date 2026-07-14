import Foundation

struct ResolvedCommand: Hashable, Sendable {
    var script: String
    var environment: [String: String]
    var recipeEnvironment: [String: String]
    var interactive: Bool
    var runsAsAdmin: Bool = false

    var shellArguments: [String] {
        interactive ? ["-ic", script] : ["-c", script]
    }

    var appleScriptSource: String {
        let escaped = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "do shell script \"\(escaped)\" with administrator privileges"
    }

    var displayString: String {
        if runsAsAdmin {
            return "osascript -e '\(appleScriptSource.replacingOccurrences(of: "'", with: "'\\''"))'"
        }
        let envPrefix = recipeEnvironment
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let shell = interactive ? "zsh -ic" : "zsh -c"
        let quoted = "'\(script.replacingOccurrences(of: "'", with: "'\\''"))'"
        return [envPrefix, shell, quoted].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

enum CommandResolutionError: LocalizedError {
    case versionTokenWithoutPinning

    var errorDescription: String? {
        switch self {
        case .versionTokenWithoutPinning:
            String(localized: "The command references a version token but the recipe has no source pinning to resolve it.")
        }
    }
}

struct CommandResolver: Sendable {
    static let basePath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    private static let latestTokens = ["{{latestTag}}", "{{latestVersion}}"]
    private static let versionToken = "{{version}}"

    let versionResolver: LatestVersionResolver

    func resolve(
        script: String,
        recipe: Recipe,
        settings: AppSettings,
        pinnedVersion: String?,
        runAsAdmin: Bool = false
    ) async throws -> ResolvedCommand {
        let expander = PathExpander(devHome: settings.devHome)
        var resolvedScript = script

        let needsLatest = Self.latestTokens.contains { script.contains($0) }
        let needsVersion = script.contains(Self.versionToken)

        if needsLatest || (needsVersion && pinnedVersion == nil) {
            guard let pinning = recipe.sourcePinning else {
                throw CommandResolutionError.versionTokenWithoutPinning
            }
            let latest = try await versionResolver.latestVersion(for: pinning)
            for token in Self.latestTokens {
                resolvedScript = resolvedScript.replacingOccurrences(of: token, with: latest)
            }
            if needsVersion, pinnedVersion == nil {
                resolvedScript = resolvedScript.replacingOccurrences(of: Self.versionToken, with: latest)
            }
        }
        if needsVersion, let pinnedVersion {
            resolvedScript = resolvedScript.replacingOccurrences(of: Self.versionToken, with: pinnedVersion)
        }

        let recipeEnvironment = expander.expandEnvironment(recipe.envVars)
        var environment = recipe.requiresInteractiveShell ? ProcessInfo.processInfo.environment : Self.baseEnvironment(expander: expander)
        environment["DEV_HOME"] = expander.expandedDevHome
        environment.merge(recipeEnvironment) { _, new in new }

        if runAsAdmin {
            resolvedScript = expander.expand(resolvedScript)
        }

        return ResolvedCommand(
            script: resolvedScript,
            environment: environment,
            recipeEnvironment: recipeEnvironment,
            interactive: recipe.requiresInteractiveShell,
            runsAsAdmin: runAsAdmin
        )
    }

    private static func baseEnvironment(expander: PathExpander) -> [String: String] {
        let inherited = ProcessInfo.processInfo.environment
        var environment: [String: String] = [:]
        environment["PATH"] = basePath
        environment["HOME"] = NSHomeDirectory()
        environment["USER"] = NSUserName()
        environment["SHELL"] = "/bin/zsh"
        environment["LANG"] = inherited["LANG"] ?? "en_US.UTF-8"
        environment["TMPDIR"] = inherited["TMPDIR"] ?? NSTemporaryDirectory()
        environment["TERM"] = "dumb"
        return environment
    }
}
