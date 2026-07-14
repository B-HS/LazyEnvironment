import SwiftUI

struct MenuBarSummaryView: View {
    @Environment(AppState.self) private var appState

    private var counts: (installed: Int, external: Int, missing: Int) {
        var installed = 0
        var external = 0
        var missing = 0
        for recipe in appState.allRecipes {
            switch appState.status(for: recipe) {
            case .installed: installed += 1
            case .installedExternally: external += 1
            case .notInstalled: missing += 1
            case .unknown, .broken: break
            }
        }
        return (installed, external, missing)
    }

    private var topConsumers: [(recipe: Recipe, bytes: Int64)] {
        appState.allRecipes
            .compactMap { recipe in
                appState.diskUsage(for: recipe).bytes.map { (recipe, $0) }
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(4)
            .map { $0 }
    }

    private var lastScan: Date? {
        appState.state.diskUsageByPath.values.map(\.updatedAt).max()
    }

    private var isBusy: Bool {
        appState.isRefreshingStatuses || appState.isScanningDisk || !appState.busyRecipeIDs.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            statChips
            diskSection
            footer
        }
        .padding(14)
        .frame(width: 336)
    }

    private var header: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.blue.gradient)
                .frame(width: 22, height: 22)
                .overlay {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            Text("Lazy Environment")
                .font(.headline)
            Spacer()
            if isBusy {
                ProgressView()
                    .controlSize(.small)
            }
            Button {
                StatusBarController.shared.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings…")
        }
    }

    private var statChips: some View {
        HStack(spacing: 8) {
            statChip(symbol: "checkmark.circle.fill", tint: .green, count: counts.installed, label: "Installed")
            statChip(symbol: "checkmark.circle", tint: .teal, count: counts.external, label: "External")
            statChip(symbol: "circle.dashed", tint: .orange, count: counts.missing, label: "Not installed")
        }
    }

    private func statChip(symbol: String, tint: Color, count: Int, label: LocalizedStringKey) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.caption)
                    .foregroundStyle(tint)
                Text("\(count)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var diskSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Managed disk usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let lastScan {
                    Text("Scanned \(lastScan.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(Formatters.byteCount(appState.totalDiskUsageBytes()))
                .font(.title2.weight(.bold))
                .monospacedDigit()

            let consumers = topConsumers
            if !consumers.isEmpty {
                let maxBytes = consumers[0].bytes
                VStack(spacing: 6) {
                    ForEach(consumers, id: \.recipe.id) { entry in
                        consumerRow(entry.recipe, bytes: entry.bytes, fraction: Double(entry.bytes) / Double(maxBytes))
                    }
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func consumerRow(_ recipe: Recipe, bytes: Int64, fraction: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: recipe.category.symbolName)
                .font(.caption2)
                .foregroundStyle(recipe.category.tint)
                .frame(width: 14)
            Text(recipe.displayName)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 96, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(recipe.category.tint.gradient)
                        .frame(width: max(4, proxy.size.width * fraction))
                }
            }
            .frame(height: 5)
            Text(Formatters.byteCount(bytes))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .trailing)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                Task {
                    await appState.refreshAllStatuses()
                    await appState.refreshAllDiskUsage()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(isBusy)
            .help("Refresh")

            Button {
                Task { await appState.updateAll() }
            } label: {
                Label("Update All", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
            .disabled(appState.isUpdatingAll)

            Spacer()

            Button {
                StatusBarController.shared.openMainWindow()
            } label: {
                Label("Show Details", systemImage: "macwindow")
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.small)
    }
}
