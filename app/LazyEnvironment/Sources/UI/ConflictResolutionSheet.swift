import SwiftUI

struct ConflictResolutionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let conflictSet: ConflictSet

    @State private var resolutions: [String: ConflictResolution] = [:]

    private var engine: SyncEngine { SyncEngine.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.orange)
                Text("Sync conflicts")
                    .font(.title3.weight(.semibold))
            }
            Text("These items differ between this Mac and the cloud. Choose per item — nothing is merged silently.")
                .font(.callout)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(conflictSet.conflicts) { conflict in
                        conflictRow(conflict)
                    }
                }
            }
            .frame(minHeight: 180, maxHeight: 360)

            HStack {
                Button("Cancel sync") {
                    engine.pendingConflicts = nil
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Apply and sync") {
                    let chosen = resolutions
                    dismiss()
                    Task { await engine.completeSync(resolutions: chosen) }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 560)
    }

    private func conflictRow(_ conflict: SyncConflict) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(conflict.displayName)
                        .font(.body.weight(.medium))
                    Spacer()
                    if let remoteUpdatedAt = conflict.remoteUpdatedAt {
                        Text("Cloud updated: \(remoteUpdatedAt)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                switch conflict.kind {
                case .preferences(let localPin, let localPath, let remotePin, let remotePath):
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
                        GridRow {
                            Text("This Mac")
                                .font(.caption.weight(.medium))
                            Text(preferenceSummary(pin: localPin, path: localPath))
                                .font(.system(.caption, design: .monospaced))
                        }
                        GridRow {
                            Text("Cloud")
                                .font(.caption.weight(.medium))
                            Text(preferenceSummary(pin: remotePin, path: remotePath))
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                    .foregroundStyle(.secondary)
                case .customRecipe:
                    Text("The custom recipe definition differs between this Mac and the cloud.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker("", selection: resolutionBinding(for: conflict)) {
                    Text("Use this Mac").tag(ConflictResolution.useLocal)
                    Text("Use cloud").tag(ConflictResolution.useCloud)
                    if case .customRecipe = conflict.kind {
                        Text("Keep both").tag(ConflictResolution.keepBoth)
                    }
                    Text("Delete").tag(ConflictResolution.deleteBoth)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func preferenceSummary(pin: String?, path: String?) -> String {
        let pinText = pin ?? "—"
        let pathText = path ?? "—"
        return "pin: \(pinText)  path: \(pathText)"
    }

    private func resolutionBinding(for conflict: SyncConflict) -> Binding<ConflictResolution> {
        Binding(
            get: { resolutions[conflict.id] ?? .useLocal },
            set: { resolutions[conflict.id] = $0 }
        )
    }
}
