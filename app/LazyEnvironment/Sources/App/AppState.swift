import Foundation
import Observation

@MainActor
@Observable
final class RecipeRun: Identifiable {
    let id = UUID()
    let recipeID: String
    let action: RecipeAction
    let commandDisplay: String
    let startedAt = Date()
    var lines: [LogLine] = []
    var exitCode: Int32?
    var isRunning = true

    init(recipeID: String, action: RecipeAction, commandDisplay: String) {
        self.recipeID = recipeID
        self.action = action
        self.commandDisplay = commandDisplay
    }
}

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    private static let maxPersistedLogCharacters = 100_000

    private let store: LocalStore
    private let diskScanner = DiskUsageScanner()
    let engine: RecipeEngine

    var settings: AppSettings {
        didSet { store.save(settings: settings) }
    }

    private(set) var builtinRecipes: [Recipe] = []
    private(set) var customRecipes: [Recipe] = []
    private(set) var state: PersistedState
    private(set) var statuses: [String: RecipeStatus] = [:]
    private(set) var externalMatches: [String: Int] = [:]
    private(set) var busyRecipeIDs: Set<String> = []
    private(set) var runs: [String: RecipeRun] = [:]
    private(set) var isUpdatingAll = false
    private(set) var isRefreshingStatuses = false
    private(set) var isScanningDisk = false

    init(store: LocalStore = LocalStore()) {
        self.store = store
        self.settings = store.loadSettings()
        self.state = store.loadState()
        self.engine = RecipeEngine(resolver: CommandResolver(versionResolver: LatestVersionResolver()))
        self.builtinRecipes = BuiltinCatalog.load()
        self.customRecipes = store.loadCustomRecipes()
    }

    var allRecipes: [Recipe] {
        builtinRecipes + customRecipes
    }

    var resolvedLocale: Locale {
        settings.language.locale ?? Locale.current
    }

    func recipes(in category: RecipeCategory) -> [Recipe] {
        allRecipes.filter { $0.category == category }
    }

    func recipe(withID id: String) -> Recipe? {
        allRecipes.first { $0.id == id }
    }

    func status(for recipe: Recipe) -> RecipeStatus {
        statuses[recipe.id] ?? .unknown
    }

    func isBusy(_ recipe: Recipe) -> Bool {
        busyRecipeIDs.contains(recipe.id)
    }

    func persistedState(for recipe: Recipe) -> RecipePersistedState {
        state.recipes[recipe.id] ?? RecipePersistedState()
    }

    func lastRun(for recipe: Recipe) -> RunRecord? {
        persistedState(for: recipe).lastRun
    }

    func pinnedVersion(for recipe: Recipe) -> String? {
        persistedState(for: recipe).pinnedVersion
    }

    func pin(version: String?, for recipe: Recipe) {
        mutatePersistedState(for: recipe) { $0.pinnedVersion = version }
    }

    func needsFirstRunConfirmation(for recipe: Recipe) -> Bool {
        settings.confirmBeforeEveryRun || !persistedState(for: recipe).hasConfirmedFirstRun
    }

    func markFirstRunConfirmed(for recipe: Recipe) {
        mutatePersistedState(for: recipe) { $0.hasConfirmedFirstRun = true }
    }

    func externalCandidate(for recipe: Recipe) -> ExternalInstallCandidate? {
        guard let index = externalMatches[recipe.id], recipe.externalCandidates.indices.contains(index) else { return nil }
        return recipe.externalCandidates[index]
    }

    func effectiveDevHome(for recipe: Recipe) -> String {
        persistedState(for: recipe).customDevHome ?? settings.devHome
    }

    func effectiveSettings(for recipe: Recipe) -> AppSettings {
        var effective = settings
        effective.devHome = effectiveDevHome(for: recipe)
        return effective
    }

    func expander(for recipe: Recipe) -> PathExpander {
        PathExpander(devHome: effectiveDevHome(for: recipe))
    }

    func setCustomDevHome(_ path: String?, for recipe: Recipe) {
        let trimmed = path?.trimmingCharacters(in: .whitespaces)
        mutatePersistedState(for: recipe) { $0.customDevHome = (trimmed?.isEmpty ?? true) ? nil : trimmed }
        let recipe = recipe
        Task {
            await refreshStatus(for: recipe)
            await refreshDiskUsage(for: recipe)
        }
    }

    func uninstallAvailable(for recipe: Recipe) -> Bool {
        engine.script(for: .uninstall, recipe: recipe, externalCandidate: externalCandidate(for: recipe)) != nil
    }

    func expandedPaths(for recipe: Recipe) -> [String] {
        let paths = externalCandidate(for: recipe)?.diskUsagePaths ?? recipe.diskUsagePaths
        return paths.map { expander(for: recipe).expand($0) }
    }

    func diskUsage(for recipe: Recipe) -> (bytes: Int64?, updatedAt: Date?) {
        let entries = expandedPaths(for: recipe).compactMap { state.diskUsageByPath[$0] }
        guard !entries.isEmpty else { return (nil, nil) }
        let total = entries.reduce(Int64(0)) { $0 + $1.bytes }
        let oldest = entries.map(\.updatedAt).min()
        return (total, oldest)
    }

    func totalDiskUsageBytes() -> Int64 {
        let uniquePaths = Set(allRecipes.flatMap { expandedPaths(for: $0) })
        return uniquePaths.compactMap { state.diskUsageByPath[$0]?.bytes }.reduce(0, +)
    }

    func recipesSharing(path: String, excluding recipe: Recipe) -> [Recipe] {
        allRecipes.filter { $0.id != recipe.id && expandedPaths(for: $0).contains(path) }
    }

    func refreshAllStatuses() async {
        guard !isRefreshingStatuses else { return }
        isRefreshingStatuses = true
        defer { isRefreshingStatuses = false }
        let snapshotRecipes = allRecipes
        let engine = engine
        await withTaskGroup(of: (String, DetectionResult).self) { group in
            for recipe in snapshotRecipes {
                let recipeSettings = effectiveSettings(for: recipe)
                group.addTask {
                    (recipe.id, await engine.detect(recipe: recipe, settings: recipeSettings))
                }
            }
            for await (recipeID, detection) in group {
                apply(detection: detection, toRecipeID: recipeID)
            }
        }
    }

    func refreshStatus(for recipe: Recipe) async {
        let detection = await engine.detect(recipe: recipe, settings: effectiveSettings(for: recipe))
        apply(detection: detection, toRecipeID: recipe.id)
    }

    private func apply(detection: DetectionResult, toRecipeID recipeID: String) {
        if let candidateIndex = detection.externalCandidateIndex {
            statuses[recipeID] = .installedExternally(version: detection.version)
            externalMatches[recipeID] = candidateIndex
        } else {
            statuses[recipeID] = detection.isInstalled ? .installed(version: detection.version) : .notInstalled
            externalMatches.removeValue(forKey: recipeID)
        }
        if detection.isInstalled, let recipe = recipe(withID: recipeID) {
            mutatePersistedState(for: recipe) { $0.lastDetectedVersion = detection.version }
        }
    }

    func refreshDiskUsage(for recipe: Recipe) async {
        await measureDiskUsage(paths: expandedPaths(for: recipe))
    }

    func refreshAllDiskUsage() async {
        guard !isScanningDisk else { return }
        isScanningDisk = true
        defer { isScanningDisk = false }
        let uniquePaths = Set(allRecipes.flatMap { expandedPaths(for: $0) })
        await measureDiskUsage(paths: Array(uniquePaths))
    }

    private func measureDiskUsage(paths: [String]) async {
        let scanner = diskScanner
        await withTaskGroup(of: (String, Int64?).self) { group in
            for path in paths {
                group.addTask {
                    (path, await scanner.measureBytes(atExpandedPath: path))
                }
            }
            for await (path, bytes) in group {
                if let bytes {
                    state.diskUsageByPath[path] = DiskUsageEntry(bytes: bytes, updatedAt: Date())
                } else {
                    state.diskUsageByPath.removeValue(forKey: path)
                }
            }
        }
        store.save(state: state)
    }

    func preview(action: RecipeAction, recipe: Recipe) async throws -> ResolvedCommand? {
        try await engine.resolvedCommand(
            for: action,
            recipe: recipe,
            settings: effectiveSettings(for: recipe),
            pinnedVersion: pinnedVersion(for: recipe),
            externalCandidate: action == .uninstall ? externalCandidate(for: recipe) : nil
        )
    }

    func run(action: RecipeAction, recipe: Recipe) async {
        guard !busyRecipeIDs.contains(recipe.id) else { return }
        busyRecipeIDs.insert(recipe.id)
        defer { busyRecipeIDs.remove(recipe.id) }

        let resolved: ResolvedCommand?
        do {
            resolved = try await preview(action: action, recipe: recipe)
        } catch {
            statuses[recipe.id] = .broken(message: error.localizedDescription)
            return
        }
        guard let resolved else { return }

        let run = RecipeRun(recipeID: recipe.id, action: action, commandDisplay: resolved.displayString)
        runs[recipe.id] = run

        for await event in engine.runner.events(for: resolved) {
            switch event {
            case .line(let line):
                run.lines.append(line)
            case .exited(let code):
                run.exitCode = code
            }
        }
        run.isRunning = false

        let logText = String(
            run.lines.map(\.text).joined(separator: "\n").suffix(Self.maxPersistedLogCharacters)
        )
        let record = RunRecord(
            action: action,
            commandDisplay: resolved.displayString,
            startedAt: run.startedAt,
            finishedAt: Date(),
            exitCode: run.exitCode,
            logText: logText
        )
        mutatePersistedState(for: recipe) { $0.lastRun = record }

        await refreshStatus(for: recipe)
        await refreshDiskUsage(for: recipe)
    }

    func updateAll() async {
        guard !isUpdatingAll else { return }
        isUpdatingAll = true
        defer { isUpdatingAll = false }
        for recipe in allRecipes {
            guard recipe.updateCommand != nil else { continue }
            guard case .installed = status(for: recipe) else { continue }
            await run(action: .update, recipe: recipe)
        }
    }

    func upsertCustomRecipe(_ recipe: Recipe) {
        if let index = customRecipes.firstIndex(where: { $0.id == recipe.id }) {
            customRecipes[index] = recipe
        } else {
            customRecipes.append(recipe)
        }
        store.save(customRecipes: customRecipes)
    }

    func deleteCustomRecipe(_ recipe: Recipe) {
        customRecipes.removeAll { $0.id == recipe.id }
        statuses.removeValue(forKey: recipe.id)
        state.recipes.removeValue(forKey: recipe.id)
        store.save(customRecipes: customRecipes)
        store.save(state: state)
    }

    func isCustom(_ recipe: Recipe) -> Bool {
        customRecipes.contains { $0.id == recipe.id }
    }

    func recordLastSync(at date: Date?) {
        state.lastSyncedAt = date
        store.save(state: state)
    }

    var lastSyncedAt: Date? {
        state.lastSyncedAt
    }

    private func mutatePersistedState(for recipe: Recipe, _ mutate: (inout RecipePersistedState) -> Void) {
        var recipeState = state.recipes[recipe.id] ?? RecipePersistedState()
        mutate(&recipeState)
        state.recipes[recipe.id] = recipeState
        store.save(state: state)
    }
}
