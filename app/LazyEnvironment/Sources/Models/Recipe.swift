import Foundation

enum RecipeCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case language
    case runtime
    case mobile
    case editor
    case aiAgent = "ai-agent"
    case custom

    var id: String { rawValue }
}

enum SourcePinning: Codable, Hashable, Sendable {
    case githubLatestTag(repo: String)
    case stableURL(url: String)
    case pinned(version: String)
    case goDevJSON

    private enum CodingKeys: String, CodingKey {
        case type
        case repo
        case url
        case version
    }

    private enum Kind: String, Codable {
        case githubLatestTag = "github-latest-tag"
        case stableURL = "stable-url"
        case pinned
        case goDevJSON = "go-dev-json"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .githubLatestTag:
            self = .githubLatestTag(repo: try container.decode(String.self, forKey: .repo))
        case .stableURL:
            self = .stableURL(url: try container.decode(String.self, forKey: .url))
        case .pinned:
            self = .pinned(version: try container.decode(String.self, forKey: .version))
        case .goDevJSON:
            self = .goDevJSON
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .githubLatestTag(let repo):
            try container.encode(Kind.githubLatestTag, forKey: .type)
            try container.encode(repo, forKey: .repo)
        case .stableURL(let url):
            try container.encode(Kind.stableURL, forKey: .type)
            try container.encode(url, forKey: .url)
        case .pinned(let version):
            try container.encode(Kind.pinned, forKey: .type)
            try container.encode(version, forKey: .version)
        case .goDevJSON:
            try container.encode(Kind.goDevJSON, forKey: .type)
        }
    }
}

struct ExternalInstallCandidate: Codable, Hashable, Sendable {
    var label: String
    var detectCommand: String
    var currentVersionCommand: String?
    var uninstallCommand: String?
    var uninstallRequiresAdmin: Bool
    var diskUsagePaths: [String]

    init(
        label: String,
        detectCommand: String,
        currentVersionCommand: String? = nil,
        uninstallCommand: String? = nil,
        uninstallRequiresAdmin: Bool = false,
        diskUsagePaths: [String] = []
    ) {
        self.label = label
        self.detectCommand = detectCommand
        self.currentVersionCommand = currentVersionCommand
        self.uninstallCommand = uninstallCommand
        self.uninstallRequiresAdmin = uninstallRequiresAdmin
        self.diskUsagePaths = diskUsagePaths
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        detectCommand = try container.decode(String.self, forKey: .detectCommand)
        currentVersionCommand = try container.decodeIfPresent(String.self, forKey: .currentVersionCommand)
        uninstallCommand = try container.decodeIfPresent(String.self, forKey: .uninstallCommand)
        uninstallRequiresAdmin = try container.decodeIfPresent(Bool.self, forKey: .uninstallRequiresAdmin) ?? false
        diskUsagePaths = try container.decodeIfPresent([String].self, forKey: .diskUsagePaths) ?? []
    }
}

struct Recipe: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var displayName: String
    var category: RecipeCategory
    var summary: String?
    var detectCommand: String?
    var currentVersionCommand: String?
    var installCommand: String?
    var updateCommand: String?
    var uninstallCommand: String?
    var envVars: [String: String]
    var diskUsagePaths: [String]
    var requiresInteractiveShell: Bool
    var brewFallbackRisk: Bool
    var supportsVersionPin: Bool
    var sourcePinning: SourcePinning?
    var lastVerified: String?
    var manualSteps: [String]
    var installActionTitle: String?
    var updateActionTitle: String?
    var externalCandidates: [ExternalInstallCandidate]
    var adminActions: [RecipeAction]
    var parentId: String?

    init(
        id: String,
        displayName: String,
        category: RecipeCategory,
        summary: String? = nil,
        detectCommand: String? = nil,
        currentVersionCommand: String? = nil,
        installCommand: String? = nil,
        updateCommand: String? = nil,
        uninstallCommand: String? = nil,
        envVars: [String: String] = [:],
        diskUsagePaths: [String] = [],
        requiresInteractiveShell: Bool = false,
        brewFallbackRisk: Bool = false,
        supportsVersionPin: Bool = false,
        sourcePinning: SourcePinning? = nil,
        lastVerified: String? = nil,
        manualSteps: [String] = [],
        installActionTitle: String? = nil,
        updateActionTitle: String? = nil,
        externalCandidates: [ExternalInstallCandidate] = [],
        adminActions: [RecipeAction] = [],
        parentId: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.category = category
        self.summary = summary
        self.detectCommand = detectCommand
        self.currentVersionCommand = currentVersionCommand
        self.installCommand = installCommand
        self.updateCommand = updateCommand
        self.uninstallCommand = uninstallCommand
        self.envVars = envVars
        self.diskUsagePaths = diskUsagePaths
        self.requiresInteractiveShell = requiresInteractiveShell
        self.brewFallbackRisk = brewFallbackRisk
        self.supportsVersionPin = supportsVersionPin
        self.sourcePinning = sourcePinning
        self.lastVerified = lastVerified
        self.manualSteps = manualSteps
        self.installActionTitle = installActionTitle
        self.updateActionTitle = updateActionTitle
        self.externalCandidates = externalCandidates
        self.adminActions = adminActions
        self.parentId = parentId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        category = try container.decode(RecipeCategory.self, forKey: .category)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        detectCommand = try container.decodeIfPresent(String.self, forKey: .detectCommand)
        currentVersionCommand = try container.decodeIfPresent(String.self, forKey: .currentVersionCommand)
        installCommand = try container.decodeIfPresent(String.self, forKey: .installCommand)
        updateCommand = try container.decodeIfPresent(String.self, forKey: .updateCommand)
        uninstallCommand = try container.decodeIfPresent(String.self, forKey: .uninstallCommand)
        envVars = try container.decodeIfPresent([String: String].self, forKey: .envVars) ?? [:]
        diskUsagePaths = try container.decodeIfPresent([String].self, forKey: .diskUsagePaths) ?? []
        requiresInteractiveShell = try container.decodeIfPresent(Bool.self, forKey: .requiresInteractiveShell) ?? false
        brewFallbackRisk = try container.decodeIfPresent(Bool.self, forKey: .brewFallbackRisk) ?? false
        supportsVersionPin = try container.decodeIfPresent(Bool.self, forKey: .supportsVersionPin) ?? false
        sourcePinning = try container.decodeIfPresent(SourcePinning.self, forKey: .sourcePinning)
        lastVerified = try container.decodeIfPresent(String.self, forKey: .lastVerified)
        manualSteps = try container.decodeIfPresent([String].self, forKey: .manualSteps) ?? []
        installActionTitle = try container.decodeIfPresent(String.self, forKey: .installActionTitle)
        updateActionTitle = try container.decodeIfPresent(String.self, forKey: .updateActionTitle)
        externalCandidates = try container.decodeIfPresent([ExternalInstallCandidate].self, forKey: .externalCandidates) ?? []
        adminActions = try container.decodeIfPresent([RecipeAction].self, forKey: .adminActions) ?? []
        parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
    }
}
