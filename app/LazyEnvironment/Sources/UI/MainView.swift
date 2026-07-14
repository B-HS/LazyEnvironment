import SwiftUI

enum SidebarSelection: Hashable {
    case all
    case category(RecipeCategory)
}

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var sidebarSelection: SidebarSelection? = .all
    @State private var selectedRecipeID: String?
    @State private var isPresentingNewRecipe = false

    private var visibleRecipes: [Recipe] {
        switch sidebarSelection {
        case .category(let category): appState.recipes(in: category)
        case .all, nil: appState.allRecipes
        }
    }

    private var rowEntries: [(recipe: Recipe, depth: Int)] {
        let visible = visibleRecipes
        let visibleIDs = Set(visible.map(\.id))
        var entries: [(recipe: Recipe, depth: Int)] = []
        for recipe in visible {
            if let parentId = recipe.parentId, visibleIDs.contains(parentId) { continue }
            entries.append((recipe, 0))
            for child in visible where child.parentId == recipe.id {
                entries.append((child, 1))
            }
        }
        return entries
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            recipeList
        } detail: {
            if let selectedRecipeID, let recipe = appState.recipe(withID: selectedRecipeID) {
                RecipeDetailView(recipe: recipe)
                    .id(recipe.id)
            } else {
                ContentUnavailableView("Select an environment", systemImage: "shippingbox")
            }
        }
        .navigationTitle("Lazy Environment")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await appState.updateAll() }
                } label: {
                    Label("Update All", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(appState.isUpdatingAll)
                .help("Update every installed environment")

                Button {
                    Task {
                        await appState.refreshAllStatuses()
                        await appState.refreshAllDiskUsage()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isRefreshingStatuses || appState.isScanningDisk)
                .help("Re-detect installs and re-scan disk usage")

                Button {
                    isPresentingNewRecipe = true
                } label: {
                    Label("Add Environment", systemImage: "plus")
                }
                .help("Add a custom environment recipe")
            }
        }
        .sheet(isPresented: $isPresentingNewRecipe) {
            CustomRecipeEditorView(original: nil)
        }
        .onAppear {
            if NSApp.activationPolicy() != .regular {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .task {
            await appState.refreshAllStatuses()
        }
    }

    private var sidebar: some View {
        List(selection: $sidebarSelection) {
            Label("All", systemImage: "square.grid.2x2")
                .tag(SidebarSelection.all)
            Section("Categories") {
                ForEach(RecipeCategory.allCases) { category in
                    HStack {
                        Label {
                            Text(category.label)
                        } icon: {
                            Image(systemName: category.symbolName)
                                .foregroundStyle(category.tint)
                        }
                        Spacer()
                        Text("\(appState.recipes(in: category).count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .tag(SidebarSelection.category(category))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Managed disk usage")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(Formatters.byteCount(appState.totalDiskUsageBytes()))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.bar)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }

    private var recipeList: some View {
        List(selection: $selectedRecipeID) {
            ForEach(rowEntries, id: \.recipe.id) { entry in
                RecipeRowView(recipe: entry.recipe, isSubRecipe: entry.depth > 0)
                    .padding(.leading, entry.depth > 0 ? 26 : 0)
                    .tag(entry.recipe.id)
            }
        }
        .overlay {
            if visibleRecipes.isEmpty {
                ContentUnavailableView("No environments", systemImage: "shippingbox")
            }
        }
        .navigationSplitViewColumnWidth(min: 320, ideal: 380)
    }
}
