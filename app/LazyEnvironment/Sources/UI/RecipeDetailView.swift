import SwiftUI
import AppKit

struct RecipeDetailView: View {
    @Environment(AppState.self) private var appState
    let recipe: Recipe

    @State private var pendingConfirmation: RecipeAction?
    @State private var isEditingRecipe = false
    @State private var isConfirmingDelete = false
    @State private var pinDraft = ""
    @State private var devHomeDraft = ""

    private var status: RecipeStatus {
        appState.status(for: recipe)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                actionRow
                warningSection
                if !recipe.manualSteps.isEmpty {
                    manualStepsSection
                }
                if recipe.supportsVersionPin {
                    pinSection
                }
                if referencesDevHome {
                    installLocationSection
                }
                if !recipe.diskUsagePaths.isEmpty {
                    pathsSection
                }
                if !recipe.envVars.isEmpty {
                    envSection
                }
                logSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toolbar {
            if appState.isCustom(recipe) {
                ToolbarItemGroup {
                    Button {
                        isEditingRecipe = true
                    } label: {
                        Label("Edit Recipe", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete Recipe", systemImage: "trash")
                    }
                }
            }
        }
        .sheet(item: $pendingConfirmation) { action in
            CommandPreviewSheet(recipe: recipe, action: action)
        }
        .sheet(isPresented: $isEditingRecipe) {
            CustomRecipeEditorView(original: recipe)
        }
        .confirmationDialog(
            "Delete this custom recipe?",
            isPresented: $isConfirmingDelete
        ) {
            Button("Delete", role: .destructive) {
                appState.deleteCustomRecipe(recipe)
            }
        } message: {
            Text("Only the recipe definition is removed. Nothing is uninstalled from disk.")
        }
        .onAppear {
            pinDraft = appState.pinnedVersion(for: recipe) ?? ""
            devHomeDraft = appState.persistedState(for: recipe).customDevHome ?? ""
        }
    }

    private var referencesDevHome: Bool {
        let sources = Array(recipe.envVars.values) + recipe.diskUsagePaths
            + [recipe.detectCommand, recipe.installCommand, recipe.updateCommand, recipe.uninstallCommand].compactMap { $0 }
        return sources.contains { $0.contains("$DEV_HOME") || $0.contains("${DEV_HOME}") }
    }

    private var installLocationSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Custom base path (empty = global dev home)", text: $devHomeDraft)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose…") { chooseCustomDevHome() }
                    Button("Apply") {
                        appState.setCustomDevHome(devHomeDraft, for: recipe)
                    }
                }
                Text("Resolves to: \(appState.expander(for: recipe).expandedDevHome)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("This recipe installs under $DEV_HOME. A custom base changes where Install puts it — and where detection and disk usage look.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Install location", systemImage: "folder")
        }
    }

    private func chooseCustomDevHome() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: appState.expander(for: recipe).expandedDevHome)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        devHomeDraft = url.path
        appState.setCustomDevHome(url.path, for: recipe)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            RecipeIconTile(category: recipe.category, size: 52)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(recipe.displayName)
                        .font(.title.weight(.semibold))
                    Label(recipe.category.label, systemImage: recipe.category.symbolName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }
                if let summary = recipe.summary {
                    Text(LocalizedStringKey(summary))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    StatusPill(status: status)
                    if let version = status.versionText {
                        Text(version)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    if case .broken(let message) = status {
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                    if let lastVerified = recipe.lastVerified {
                        Text("Recipe last verified: \(lastVerified)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            if recipe.installCommand != nil {
                actionButton(.install, title: recipe.installActionTitle, prominent: !isInstalled)
            }
            if recipe.updateCommand != nil {
                actionButton(.update, title: recipe.updateActionTitle, prominent: isInstalled)
            }
            if appState.uninstallAvailable(for: recipe) {
                Button(role: .destructive) {
                    pendingConfirmation = .uninstall
                } label: {
                    Text(RecipeAction.uninstall.label)
                }
                .disabled(appState.isBusy(recipe))
            }
            if appState.isBusy(recipe) {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 4)
            }
        }
    }

    private var isInstalled: Bool {
        if case .installed = status { return true }
        return false
    }

    private func actionButton(_ action: RecipeAction, title: String?, prominent: Bool) -> some View {
        Button {
            if appState.needsFirstRunConfirmation(for: recipe) {
                pendingConfirmation = action
            } else {
                Task { await appState.run(action: action, recipe: recipe) }
            }
        } label: {
            if let title {
                Text(LocalizedStringKey(title))
            } else {
                Text(action.label)
            }
        }
        .buttonStyle(.bordered)
        .tint(prominent ? .accentColor : nil)
        .disabled(appState.isBusy(recipe))
        .contextMenu {
            Button("Review command first…") {
                pendingConfirmation = action
            }
        }
    }

    @ViewBuilder
    private var warningSection: some View {
        if case .installedExternally = status, let candidate = appState.externalCandidate(for: recipe) {
            GroupBox {
                VStack(alignment: .leading, spacing: 4) {
                    (Text("Existing install detected:") + Text(verbatim: " ") + Text(LocalizedStringKey(candidate.label)))
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("This install lives outside the managed layout. Install sets up a separate managed copy under your dev home and leaves the existing one untouched.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if candidate.uninstallCommand != nil {
                        Text("Uninstall removes this detected existing install — review the exact command before running.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("External install", systemImage: "checkmark.circle")
                    .foregroundStyle(.teal)
            }
        }
        if recipe.brewFallbackRisk {
            Label(
                "The upstream official installer for this tool can silently fall back to Homebrew. This recipe uses a brew-free method — keep that in mind if you edit it.",
                systemImage: "exclamationmark.shield"
            )
            .font(.callout)
            .foregroundStyle(.orange)
        }
        if recipe.requiresInteractiveShell {
            Label(
                "This tool is a shell function, not a binary. Commands run via an interactive shell (zsh -ic).",
                systemImage: "terminal"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private var manualStepsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(recipe.manualSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1).")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text(LocalizedStringKey(step))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Manual steps (cannot be scripted)", systemImage: "hand.raised")
        }
    }

    private var pinSection: some View {
        GroupBox {
            HStack {
                TextField("Pinned version (empty = always latest)", text: $pinDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Apply") {
                    let trimmed = pinDraft.trimmingCharacters(in: .whitespaces)
                    appState.pin(version: trimmed.isEmpty ? nil : trimmed, for: recipe)
                }
            }
        } label: {
            Label("Version pin", systemImage: "pin")
        }
    }

    private var pathsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(appState.expandedPaths(for: recipe), id: \.self) { path in
                    pathRow(path)
                }
                HStack {
                    if let updatedAt = appState.diskUsage(for: recipe).updatedAt {
                        Text("Disk usage measured \(updatedAt.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Rescan") {
                        let recipe = recipe
                        Task { await appState.refreshDiskUsage(for: recipe) }
                    }
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Paths on disk", systemImage: "internaldrive")
        }
    }

    private func pathRow(_ path: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.abbreviatePath(path))
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                let sharing = appState.recipesSharing(path: path, excluding: recipe)
                if !sharing.isEmpty {
                    Text("Shared with \(sharing.map(\.displayName).joined(separator: ", ")) — counted once in totals")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let bytes = appState.state.diskUsageByPath[path]?.bytes {
                Text(Formatters.byteCount(bytes))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var envSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                let expander = appState.expander(for: recipe)
                ForEach(recipe.envVars.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    Text("\(key)=\(expander.expand(value))")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Text("Add these to your shell profile so the tools resolve the same paths in your terminal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Copy export lines") { copyExportLines() }
                        .controlSize(.small)
                }
                .padding(.top, 4)
            }
        } label: {
            Label("Environment variables", systemImage: "list.bullet.rectangle")
        }
    }

    private func copyExportLines() {
        let expander = appState.expander(for: recipe)
        let lines = recipe.envVars
            .sorted { $0.key < $1.key }
            .map { "export \($0.key)=\"\(expander.expand($0.value))\"" }
            .joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines, forType: .string)
    }

    @ViewBuilder
    private var logSection: some View {
        if let run = appState.runs[recipe.id] {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text(run.commandDisplay)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    LogView(lines: run.lines, isRunning: run.isRunning)
                        .frame(minHeight: 160, maxHeight: 320)
                    if let exitCode = run.exitCode {
                        Label(
                            exitCode == 0 ? "Finished successfully" : "Exited with code \(exitCode)",
                            systemImage: exitCode == 0 ? "checkmark.circle" : "xmark.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(exitCode == 0 ? .green : .red)
                    }
                }
            } label: {
                Label(run.isRunning ? "Running — \(Text(run.action.label))" : "Last run — \(Text(run.action.label))", systemImage: "text.alignleft")
            }
        } else if let record = appState.lastRun(for: recipe) {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.commandDisplay)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    ScrollView {
                        Text(record.logText.isEmpty ? String(localized: "No output") : record.logText)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(minHeight: 120, maxHeight: 280)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    HStack(spacing: 12) {
                        if let exitCode = record.exitCode {
                            Label(
                                exitCode == 0 ? "Succeeded" : "Failed (exit \(exitCode))",
                                systemImage: exitCode == 0 ? "checkmark.circle" : "xmark.circle"
                            )
                            .foregroundStyle(exitCode == 0 ? .green : .red)
                        }
                        Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            } label: {
                Label("Last run — \(Text(record.action.label))", systemImage: "text.alignleft")
            }
        }
    }
}
