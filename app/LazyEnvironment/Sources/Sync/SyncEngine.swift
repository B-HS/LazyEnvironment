import Foundation
import AppKit
import AuthenticationServices
import Observation

struct SyncConflict: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case preferences(localPin: String?, localPath: String?, remotePin: String?, remotePath: String?)
        case customRecipe(local: Recipe, remote: Recipe)
    }

    let id: String
    let displayName: String
    let kind: Kind
    let remoteUpdatedAt: String?
}

enum ConflictResolution: Hashable, Sendable {
    case useLocal
    case useCloud
    case keepBoth
    case deleteBoth
}

struct ConflictSet: Identifiable {
    let id = UUID()
    var conflicts: [SyncConflict]
    var remote: SyncProfilePayload
}

@MainActor
@Observable
final class SyncEngine: NSObject {
    static let shared = SyncEngine()

    private let tokenStore = KeychainStore(account: "session-token")
    private let loginStore = KeychainStore(account: "session-login")
    private var authSession: ASWebAuthenticationSession?

    enum ConnectionStatus: Hashable, Sendable {
        case unknown
        case online
        case offline
    }

    private(set) var accountLogin: String?
    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?
    private(set) var connectionStatus: ConnectionStatus = .unknown
    private(set) var lastConnectionCheckAt: Date?
    var connectionAlert: String?
    var lastError: String?
    var pendingConflicts: ConflictSet?

    var isSignedIn: Bool { tokenStore.read() != nil }

    var isOfflineMode: Bool { AppState.shared.settings.syncMode == .offline }

    override init() {
        super.init()
        accountLogin = loginStore.read()
    }

    private var appState: AppState { AppState.shared }

    private func client() throws -> SyncClient {
        guard let url = URL(string: appState.settings.syncServerURL) else {
            throw SyncError.invalidServerURL
        }
        return SyncClient(baseURL: url, token: tokenStore.read())
    }

    @discardableResult
    func checkConnection(announce: Bool) async -> Bool {
        do {
            _ = try await client().fetchHealth()
            connectionStatus = .online
            lastConnectionCheckAt = Date()
            if announce {
                connectionAlert = String(localized: "Connected to the sync server.")
            }
            return true
        } catch {
            connectionStatus = .offline
            lastConnectionCheckAt = Date()
            if announce {
                connectionAlert = String(localized: "Could not reach the sync server: \(error.localizedDescription)")
            }
            return false
        }
    }

    private func guardOnlineMode() -> Bool {
        guard isOfflineMode else { return true }
        lastError = String(localized: "Offline mode is on. Switch to online mode to sync.")
        return false
    }

    func signInWithGitHub() {
        lastError = nil
        guard guardOnlineMode() else { return }
        guard let startURL = URL(string: appState.settings.syncServerURL)?.appendingPathComponent("auth/github") else {
            lastError = SyncError.invalidServerURL.localizedDescription
            return
        }
        let session = ASWebAuthenticationSession(url: startURL, callbackURLScheme: "lazyenvironment") { @Sendable [weak self] callbackURL, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.lastError = error.localizedDescription
                    return
                }
                self.handleCallback(callbackURL)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        authSession = session
        session.start()
    }

    func cancelSignIn() {
        authSession?.cancel()
        authSession = nil
    }

    private func handleCallback(_ callbackURL: URL?) {
        guard let callbackURL,
              let fragment = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.fragment else {
            lastError = String(localized: "Sign-in was cancelled or returned no token.")
            return
        }
        var values: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            values[String(parts[0])] = String(parts[1]).removingPercentEncoding ?? String(parts[1])
        }
        if let errorCode = values["error"] {
            lastError = String(localized: "Sign-in failed: \(errorCode)")
            return
        }
        guard let token = values["token"] else {
            lastError = String(localized: "Sign-in was cancelled or returned no token.")
            return
        }
        tokenStore.write(token)
        if let login = values["login"] {
            loginStore.write(login)
            accountLogin = login
        }
        Task { await sync() }
    }

    func signInDev(login: String) async {
        lastError = nil
        guard guardOnlineMode() else { return }
        do {
            let payload = try await client().devLogin(login: login)
            tokenStore.write(payload.token)
            loginStore.write(payload.login)
            accountLogin = payload.login
            await sync()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut() {
        tokenStore.delete()
        loginStore.delete()
        accountLogin = nil
        pendingConflicts = nil
        lastSyncedAt = nil
    }

    func sync() async {
        guard !isSyncing else { return }
        guard guardOnlineMode() else { return }
        guard isSignedIn else {
            lastError = SyncError.notSignedIn.localizedDescription
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        lastError = nil
        guard await checkConnection(announce: false) else {
            lastError = String(localized: "Could not reach the sync server: \(appState.settings.syncServerURL)")
            return
        }
        do {
            let remote = try await client().fetchProfile()
            let conflicts = computeConflicts(remote: remote)
            if conflicts.isEmpty {
                applyRemoteOnlyValues(remote: remote)
                try await push()
            } else {
                pendingConflicts = ConflictSet(conflicts: conflicts, remote: remote)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func completeSync(resolutions: [String: ConflictResolution]) async {
        guard let pending = pendingConflicts else { return }
        pendingConflicts = nil
        applyResolutions(pending: pending, resolutions: resolutions)
        do {
            try await push()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func computeConflicts(remote: SyncProfilePayload) -> [SyncConflict] {
        var conflicts: [SyncConflict] = []
        for entry in remote.environments {
            guard let recipe = appState.recipe(withID: entry.recipeId) else { continue }
            let local = appState.persistedState(for: recipe)
            let localHasValues = local.pinnedVersion != nil || local.customDevHome != nil
            let differs = local.pinnedVersion != entry.pinnedVersion || local.customDevHome != entry.customPath
            if localHasValues, differs {
                conflicts.append(SyncConflict(
                    id: entry.recipeId,
                    displayName: recipe.displayName,
                    kind: .preferences(
                        localPin: local.pinnedVersion,
                        localPath: local.customDevHome,
                        remotePin: entry.pinnedVersion,
                        remotePath: entry.customPath
                    ),
                    remoteUpdatedAt: entry.updatedAt
                ))
            }
        }
        for entry in remote.customRecipes {
            guard let local = appState.customRecipes.first(where: { $0.id == entry.recipeId }) else { continue }
            if local != entry.recipe {
                conflicts.append(SyncConflict(
                    id: entry.recipeId,
                    displayName: local.displayName,
                    kind: .customRecipe(local: local, remote: entry.recipe),
                    remoteUpdatedAt: entry.updatedAt
                ))
            }
        }
        return conflicts
    }

    private func applyRemoteOnlyValues(remote: SyncProfilePayload) {
        for entry in remote.environments {
            guard let recipe = appState.recipe(withID: entry.recipeId) else { continue }
            let local = appState.persistedState(for: recipe)
            if local.pinnedVersion == nil, let pin = entry.pinnedVersion {
                appState.pin(version: pin, for: recipe)
            }
            if local.customDevHome == nil, let path = entry.customPath {
                appState.setCustomDevHome(path, for: recipe)
            }
        }
        for entry in remote.customRecipes where appState.recipe(withID: entry.recipeId) == nil {
            appState.upsertCustomRecipe(entry.recipe)
        }
    }

    private func applyResolutions(pending: ConflictSet, resolutions: [String: ConflictResolution]) {
        applyRemoteOnlyValues(remote: pending.remote)
        for conflict in pending.conflicts {
            let resolution = resolutions[conflict.id] ?? .useLocal
            switch (conflict.kind, resolution) {
            case (.preferences, .useLocal), (.customRecipe, .useLocal):
                continue
            case (.preferences(_, _, let remotePin, let remotePath), .useCloud):
                guard let recipe = appState.recipe(withID: conflict.id) else { continue }
                appState.pin(version: remotePin, for: recipe)
                appState.setCustomDevHome(remotePath, for: recipe)
            case (.preferences, .deleteBoth):
                guard let recipe = appState.recipe(withID: conflict.id) else { continue }
                appState.pin(version: nil, for: recipe)
                appState.setCustomDevHome(nil, for: recipe)
            case (.preferences, .keepBoth):
                continue
            case (.customRecipe(_, let remote), .useCloud):
                appState.upsertCustomRecipe(remote)
            case (.customRecipe(let local, _), .deleteBoth):
                appState.deleteCustomRecipe(local)
            case (.customRecipe(_, var remote), .keepBoth):
                remote.id = "\(remote.id)-cloud"
                remote.displayName = "\(remote.displayName) (Cloud)"
                if appState.recipe(withID: remote.id) == nil {
                    appState.upsertCustomRecipe(remote)
                }
            }
        }
    }

    private func push() async throws {
        let environments: [SyncEnvironmentEntry] = appState.allRecipes.compactMap { recipe in
            let state = appState.persistedState(for: recipe)
            guard state.pinnedVersion != nil || state.customDevHome != nil else { return nil }
            return SyncEnvironmentEntry(
                recipeId: recipe.id,
                pinnedVersion: state.pinnedVersion,
                customPath: state.customDevHome,
                enabled: true,
                updatedAt: nil
            )
        }
        let customRecipes = appState.customRecipes.map {
            SyncCustomRecipeEntry(recipeId: $0.id, recipe: $0, updatedAt: nil)
        }
        _ = try await client().pushProfile(SyncProfilePush(environments: environments, customRecipes: customRecipes))
        lastSyncedAt = Date()
        appState.recordLastSync(at: lastSyncedAt)
    }
}

extension SyncEngine: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible } ?? ASPresentationAnchor()
        }
    }
}
