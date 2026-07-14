import SwiftUI

struct CommandPreviewSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    let action: RecipeAction

    @State private var resolved: ResolvedCommand?
    @State private var resolutionError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                Text("Review command")
                    .font(.title3.weight(.semibold))
            }
            Text("\(recipe.displayName) — \(Text(action.label))")
                .foregroundStyle(.secondary)

            if let resolutionError {
                Label(resolutionError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            } else if let resolved {
                if !resolved.recipeEnvironment.isEmpty {
                    GroupBox("Environment") {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(resolved.recipeEnvironment.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                Text("\(key)=\(value)")
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                GroupBox("Command") {
                    ScrollView {
                        Text(resolved.script)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 160)
                }
                if resolved.interactive {
                    Label("Runs in an interactive login shell (zsh -ic) because this tool is a shell function.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if resolved.runsAsAdmin {
                    Label("Runs with administrator privileges — macOS will ask for your password.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Resolving command…")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Run") {
                    appState.markFirstRunConfirmed(for: recipe)
                    let recipe = recipe
                    let action = action
                    Task { await appState.run(action: action, recipe: recipe) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(resolved == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 520)
        .task {
            do {
                resolved = try await appState.preview(action: action, recipe: recipe)
                if resolved == nil {
                    resolutionError = String(localized: "This recipe does not define a command for this action.")
                }
            } catch {
                resolutionError = error.localizedDescription
            }
        }
    }
}
