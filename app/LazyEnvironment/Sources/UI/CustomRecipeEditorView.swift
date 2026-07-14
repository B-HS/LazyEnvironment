import SwiftUI

private enum EditorTab: Hashable {
    case form
    case json
}

private enum PinningKind: String, CaseIterable, Identifiable {
    case none
    case githubLatestTag
    case stableURL
    case pinned
    case goDevJSON

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .none: "None"
        case .githubLatestTag: "GitHub latest tag"
        case .stableURL: "Stable vendor URL"
        case .pinned: "Pinned version"
        case .goDevJSON: "go.dev release feed"
        }
    }

    var valuePrompt: LocalizedStringKey? {
        switch self {
        case .none, .goDevJSON: nil
        case .githubLatestTag: "owner/repo"
        case .stableURL: "https://…"
        case .pinned: "version"
        }
    }
}

struct CustomRecipeEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let original: Recipe?

    @State private var tab: EditorTab = .form
    @State private var recipeID = ""
    @State private var displayName = ""
    @State private var summary = ""
    @State private var category: RecipeCategory = .custom
    @State private var detectCommand = ""
    @State private var currentVersionCommand = ""
    @State private var installCommand = ""
    @State private var updateCommand = ""
    @State private var uninstallCommand = ""
    @State private var envVarsText = ""
    @State private var pathsText = ""
    @State private var manualStepsText = ""
    @State private var requiresInteractiveShell = false
    @State private var brewFallbackRisk = false
    @State private var supportsVersionPin = false
    @State private var pinningKind: PinningKind = .none
    @State private var pinningValue = ""
    @State private var jsonText = ""
    @State private var validationError: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(original == nil ? "Add custom environment" : "Edit custom environment")
                    .font(.title3.weight(.semibold))
                Spacer()
                Picker("", selection: $tab) {
                    Text("Form").tag(EditorTab.form)
                    Text("JSON").tag(EditorTab.json)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            if tab == .form {
                formEditor
            } else {
                jsonEditor
            }

            if let validationError {
                Label(validationError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 680, height: 680)
        .onAppear { load() }
        .onChange(of: tab) { _, newTab in
            if newTab == .json {
                jsonText = encodeCurrentForm()
            }
        }
    }

    private var formEditor: some View {
        Form {
            Section("Identity") {
                TextField("ID (kebab-case, unique)", text: $recipeID)
                TextField("Display name", text: $displayName)
                TextField("Summary", text: $summary)
                Picker("Category", selection: $category) {
                    ForEach(RecipeCategory.allCases) { category in
                        Text(category.label).tag(category)
                    }
                }
            }
            Section("Commands") {
                TextField("Detect (exit 0 = installed)", text: $detectCommand, axis: .vertical)
                TextField("Current version", text: $currentVersionCommand, axis: .vertical)
                TextField("Install", text: $installCommand, axis: .vertical)
                TextField("Update", text: $updateCommand, axis: .vertical)
                TextField("Uninstall", text: $uninstallCommand, axis: .vertical)
                Text("Tokens: {{latestTag}} / {{latestVersion}} resolve from source pinning, {{version}} prefers the pinned version.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Environment & paths") {
                TextField("Environment variables (KEY=VALUE per line)", text: $envVarsText, axis: .vertical)
                    .lineLimit(2...5)
                TextField("Disk usage paths (one per line, $DEV_HOME and ~ allowed)", text: $pathsText, axis: .vertical)
                    .lineLimit(2...5)
                TextField("Manual steps (one per line)", text: $manualStepsText, axis: .vertical)
                    .lineLimit(1...4)
            }
            Section("Behavior") {
                Toggle("Requires interactive shell (tool is a shell function, e.g. nvm, sdk)", isOn: $requiresInteractiveShell)
                Toggle("Official installer has Homebrew fallback risk", isOn: $brewFallbackRisk)
                Toggle("Supports version pinning", isOn: $supportsVersionPin)
            }
            Section("Source pinning") {
                Picker("How is \u{201C}latest\u{201D} resolved?", selection: $pinningKind) {
                    ForEach(PinningKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                if let prompt = pinningKind.valuePrompt {
                    TextField(prompt, text: $pinningValue)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var jsonEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $jsonText)
                .font(.system(.callout, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Button("Apply JSON to form") { applyJSONToForm() }
        }
    }

    private func load() {
        guard let original else { return }
        recipeID = original.id
        displayName = original.displayName
        summary = original.summary ?? ""
        category = original.category
        detectCommand = original.detectCommand ?? ""
        currentVersionCommand = original.currentVersionCommand ?? ""
        installCommand = original.installCommand ?? ""
        updateCommand = original.updateCommand ?? ""
        uninstallCommand = original.uninstallCommand ?? ""
        envVarsText = original.envVars.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        pathsText = original.diskUsagePaths.joined(separator: "\n")
        manualStepsText = original.manualSteps.joined(separator: "\n")
        requiresInteractiveShell = original.requiresInteractiveShell
        brewFallbackRisk = original.brewFallbackRisk
        supportsVersionPin = original.supportsVersionPin
        switch original.sourcePinning {
        case .githubLatestTag(let repo):
            pinningKind = .githubLatestTag
            pinningValue = repo
        case .stableURL(let url):
            pinningKind = .stableURL
            pinningValue = url
        case .pinned(let version):
            pinningKind = .pinned
            pinningValue = version
        case .goDevJSON:
            pinningKind = .goDevJSON
        case nil:
            pinningKind = .none
        }
    }

    private func buildRecipeFromForm() -> Recipe? {
        let id = recipeID.trimmingCharacters(in: .whitespaces)
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else {
            validationError = String(localized: "ID is required.")
            return nil
        }
        guard !name.isEmpty else {
            validationError = String(localized: "Display name is required.")
            return nil
        }
        if original?.id != id, appState.recipe(withID: id) != nil {
            validationError = String(localized: "A recipe with this ID already exists.")
            return nil
        }

        var envVars: [String: String] = [:]
        for line in nonEmptyLines(envVarsText) {
            guard let separatorIndex = line.firstIndex(of: "=") else {
                validationError = String(localized: "Environment variable line \u{201C}\(line)\u{201D} is not KEY=VALUE.")
                return nil
            }
            let key = String(line[line.startIndex..<separatorIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else {
                validationError = String(localized: "Environment variable line \u{201C}\(line)\u{201D} has an empty key.")
                return nil
            }
            envVars[key] = value
        }

        let pinning: SourcePinning?
        switch pinningKind {
        case .none:
            pinning = nil
        case .githubLatestTag:
            let repo = pinningValue.trimmingCharacters(in: .whitespaces)
            guard repo.contains("/") else {
                validationError = String(localized: "GitHub pinning requires owner/repo.")
                return nil
            }
            pinning = .githubLatestTag(repo: repo)
        case .stableURL:
            pinning = .stableURL(url: pinningValue.trimmingCharacters(in: .whitespaces))
        case .pinned:
            pinning = .pinned(version: pinningValue.trimmingCharacters(in: .whitespaces))
        case .goDevJSON:
            pinning = .goDevJSON
        }

        return Recipe(
            id: id,
            displayName: name,
            category: category,
            summary: emptyToNil(summary),
            detectCommand: emptyToNil(detectCommand),
            currentVersionCommand: emptyToNil(currentVersionCommand),
            installCommand: emptyToNil(installCommand),
            updateCommand: emptyToNil(updateCommand),
            uninstallCommand: emptyToNil(uninstallCommand),
            envVars: envVars,
            diskUsagePaths: nonEmptyLines(pathsText),
            requiresInteractiveShell: requiresInteractiveShell,
            brewFallbackRisk: brewFallbackRisk,
            supportsVersionPin: supportsVersionPin,
            sourcePinning: pinning,
            manualSteps: nonEmptyLines(manualStepsText)
        )
    }

    private func encodeCurrentForm() -> String {
        validationError = nil
        guard let recipe = buildRecipeFromForm() else { return jsonText }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(recipe) else { return jsonText }
        return String(decoding: data, as: UTF8.self)
    }

    private func applyJSONToForm() {
        validationError = nil
        do {
            let recipe = try JSONDecoder().decode(Recipe.self, from: Data(jsonText.utf8))
            applyToForm(recipe)
            tab = .form
        } catch {
            validationError = String(localized: "Invalid recipe JSON: \(error.localizedDescription)")
        }
    }

    private func applyToForm(_ recipe: Recipe) {
        recipeID = recipe.id
        displayName = recipe.displayName
        summary = recipe.summary ?? ""
        category = recipe.category
        detectCommand = recipe.detectCommand ?? ""
        currentVersionCommand = recipe.currentVersionCommand ?? ""
        installCommand = recipe.installCommand ?? ""
        updateCommand = recipe.updateCommand ?? ""
        uninstallCommand = recipe.uninstallCommand ?? ""
        envVarsText = recipe.envVars.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        pathsText = recipe.diskUsagePaths.joined(separator: "\n")
        manualStepsText = recipe.manualSteps.joined(separator: "\n")
        requiresInteractiveShell = recipe.requiresInteractiveShell
        brewFallbackRisk = recipe.brewFallbackRisk
        supportsVersionPin = recipe.supportsVersionPin
        switch recipe.sourcePinning {
        case .githubLatestTag(let repo):
            pinningKind = .githubLatestTag
            pinningValue = repo
        case .stableURL(let url):
            pinningKind = .stableURL
            pinningValue = url
        case .pinned(let version):
            pinningKind = .pinned
            pinningValue = version
        case .goDevJSON:
            pinningKind = .goDevJSON
        case nil:
            pinningKind = .none
        }
    }

    private func save() {
        validationError = nil
        let recipe: Recipe?
        if tab == .json {
            do {
                recipe = try JSONDecoder().decode(Recipe.self, from: Data(jsonText.utf8))
            } catch {
                validationError = String(localized: "Invalid recipe JSON: \(error.localizedDescription)")
                return
            }
        } else {
            recipe = buildRecipeFromForm()
        }
        guard let recipe else { return }
        if let original, original.id != recipe.id {
            appState.deleteCustomRecipe(original)
        }
        appState.upsertCustomRecipe(recipe)
        dismiss()
    }

    private func nonEmptyLines(_ text: String) -> [String] {
        text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func emptyToNil(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
