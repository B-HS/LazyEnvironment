import SwiftUI

struct RecipeRowView: View {
    @Environment(AppState.self) private var appState
    let recipe: Recipe
    var isSubRecipe: Bool = false

    private var status: RecipeStatus {
        appState.status(for: recipe)
    }

    var body: some View {
        HStack(spacing: 10) {
            RecipeIconTile(category: recipe.category, size: isSubRecipe ? 24 : 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(recipe.displayName)
                        .font(.body.weight(.medium))
                    if recipe.brewFallbackRisk {
                        Image(systemName: "exclamationmark.shield")
                            .foregroundStyle(.orange)
                            .help("Official installer may silently fall back to Homebrew")
                    }
                }
                if let primaryPath = appState.expandedPaths(for: recipe).first {
                    Text(Formatters.abbreviatePath(primaryPath))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                StatusPill(status: status)
                HStack(spacing: 6) {
                    if let version = status.versionText {
                        Text(version)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if let bytes = appState.diskUsage(for: recipe).bytes, bytes > 0 {
                        Text(Formatters.byteCount(bytes))
                            .monospacedDigit()
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            rowAction
                .frame(width: 76, alignment: .trailing)
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private var rowAction: some View {
        if appState.isBusy(recipe) {
            ProgressView()
                .controlSize(.small)
        } else {
            switch status {
            case .notInstalled where recipe.installCommand != nil,
                 .installedExternally where recipe.installCommand != nil:
                RunActionButton(recipe: recipe, action: .install, title: recipe.installActionTitle)
            case .installed where recipe.updateCommand != nil:
                RunActionButton(recipe: recipe, action: .update, title: recipe.updateActionTitle)
            default:
                EmptyView()
            }
        }
    }
}

struct RunActionButton: View {
    @Environment(AppState.self) private var appState
    let recipe: Recipe
    let action: RecipeAction
    let title: String?
    @State private var pendingConfirmation: RecipeAction?

    var body: some View {
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
        .controlSize(.small)
        .disabled(appState.isBusy(recipe))
        .sheet(item: $pendingConfirmation) { confirmed in
            CommandPreviewSheet(recipe: recipe, action: confirmed)
        }
    }
}
