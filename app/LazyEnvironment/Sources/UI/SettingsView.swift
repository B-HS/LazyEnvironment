import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?
    @State private var devLoginName = ""

    private var syncEngine: SyncEngine { SyncEngine.shared }

    var body: some View {
        @Bindable var appState = appState
        Form {
            Section("General") {
                HStack {
                    TextField("Dev home directory", text: $appState.settings.devHome)
                    Button("Choose…") { chooseDevHome() }
                }
                LabeledContent("Resolves to", value: PathExpander(devHome: appState.settings.devHome).expandedDevHome)
                Picker("Language", selection: $appState.settings.language) {
                    Text("System").tag(LanguageOption.system)
                    Text(verbatim: "한국어").tag(LanguageOption.korean)
                    Text(verbatim: "English").tag(LanguageOption.english)
                    Text(verbatim: "日本語").tag(LanguageOption.japanese)
                }
            }
            Section("App") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Toggle("Show menu bar icon", isOn: menuBarEnabledBinding)
                Toggle("Start hidden in the menu bar (no main window, no Dock icon)", isOn: $appState.settings.startInMenuBar)
                    .disabled(!appState.settings.menuBarEnabled)
            }
            Section("Execution") {
                Toggle("Always review commands before running", isOn: $appState.settings.confirmBeforeEveryRun)
                Text("Commands are always shown for the first run of each recipe. Enable this to review on every run.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Account & Sync") {
                Picker("Sync mode", selection: $appState.settings.syncMode) {
                    Text("Online").tag(SyncMode.online)
                    Text("Offline").tag(SyncMode.offline)
                }
                .pickerStyle(.segmented)
                if appState.settings.syncMode == .offline {
                    Text("Offline mode — sync and sign-in are disabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextField("Sync server URL", text: $appState.settings.syncServerURL)
                    .disabled(appState.settings.syncMode == .offline)
                Text("Self-hosting is supported — run your own server instance and point this URL at it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Circle()
                        .fill(connectionTint)
                        .frame(width: 8, height: 8)
                    Text(connectionLabel)
                        .font(.callout)
                    if let checkedAt = syncEngine.lastConnectionCheckAt {
                        Text("Checked \(checkedAt.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Test Connection") {
                        Task { await syncEngine.checkConnection(announce: true) }
                    }
                    .disabled(appState.settings.syncMode == .offline)
                }
                if syncEngine.isSignedIn {
                    LabeledContent("Signed in as", value: syncEngine.accountLogin ?? "—")
                    if let lastSyncedAt = appState.lastSyncedAt {
                        LabeledContent("Last synced", value: lastSyncedAt.formatted(.relative(presentation: .named)))
                    }
                    HStack {
                        Button("Sync Now") {
                            Task { await syncEngine.sync() }
                        }
                        .disabled(syncEngine.isSyncing || appState.settings.syncMode == .offline)
                        if syncEngine.isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Spacer()
                        Button("Sign Out", role: .destructive) {
                            syncEngine.signOut()
                        }
                    }
                } else {
                    Button("Sign in with GitHub") {
                        syncEngine.signInWithGitHub()
                    }
                    .disabled(appState.settings.syncMode == .offline)
                    #if DEBUG
                    HStack {
                        TextField("Dev login name", text: $devLoginName)
                        Button("Dev Sign-In") {
                            let login = devLoginName.trimmingCharacters(in: .whitespaces)
                            guard !login.isEmpty else { return }
                            Task { await syncEngine.signInDev(login: login) }
                        }
                    }
                    #endif
                }
                if let lastError = syncEngine.lastError {
                    Text(lastError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
            Section("Disk usage") {
                Text("Disk usage is scanned only when you ask for it (Refresh or Rescan). The last measurement time is stored and shown per path.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Data") {
                LabeledContent("Local data", value: Formatters.abbreviatePath(LocalStore.defaultDirectory().path))
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([LocalStore.defaultDirectory()])
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .sheet(item: Binding(get: { syncEngine.pendingConflicts }, set: { syncEngine.pendingConflicts = $0 })) { conflictSet in
            ConflictResolutionSheet(conflictSet: conflictSet)
        }
        .alert(
            "Server connection",
            isPresented: Binding(get: { syncEngine.connectionAlert != nil }, set: { if !$0 { syncEngine.connectionAlert = nil } })
        ) {
            Button("OK") { syncEngine.connectionAlert = nil }
        } message: {
            Text(syncEngine.connectionAlert ?? "")
        }
        .onChange(of: launchAtLogin) { _, enabled in
            launchAtLoginError = nil
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLoginError = error.localizedDescription
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private var connectionTint: Color {
        switch syncEngine.connectionStatus {
        case .unknown: .gray
        case .online: .green
        case .offline: .red
        }
    }

    private var connectionLabel: LocalizedStringKey {
        switch syncEngine.connectionStatus {
        case .unknown: "Not checked yet"
        case .online: "Online"
        case .offline: "Offline"
        }
    }

    private var menuBarEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.menuBarEnabled },
            set: { enabled in
                appState.settings.menuBarEnabled = enabled
                if enabled {
                    StatusBarController.shared.install(appState: appState)
                } else {
                    StatusBarController.shared.remove()
                    NSApp.setActivationPolicy(.regular)
                }
            }
        )
    }

    private func chooseDevHome() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: PathExpander(devHome: appState.settings.devHome).expandedDevHome)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        appState.settings.devHome = url.path
    }
}
