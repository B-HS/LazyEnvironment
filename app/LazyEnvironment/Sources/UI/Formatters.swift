import Foundation
import SwiftUI

enum Formatters {
    static func byteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func abbreviatePath(_ path: String) -> String {
        let home = NSHomeDirectory()
        guard path.hasPrefix(home) else { return path }
        return "~" + path.dropFirst(home.count)
    }
}

extension RecipeStatus {
    var label: LocalizedStringKey {
        switch self {
        case .unknown: "Checking"
        case .notInstalled: "Not installed"
        case .installed(let version): version.map { LocalizedStringKey(stringLiteral: $0) } ?? "Installed"
        case .installedExternally(let version): version.map { LocalizedStringKey(stringLiteral: $0) } ?? "Installed (external)"
        case .broken: "Broken"
        }
    }

    var pillLabel: LocalizedStringKey {
        switch self {
        case .unknown: "Checking"
        case .notInstalled: "Not installed"
        case .installed: "Installed"
        case .installedExternally: "External"
        case .broken: "Broken"
        }
    }

    var versionText: String? {
        switch self {
        case .installed(let version), .installedExternally(let version): version
        case .unknown, .notInstalled, .broken: nil
        }
    }

    var tint: Color {
        switch self {
        case .unknown: .secondary
        case .notInstalled: .orange
        case .installed: .green
        case .installedExternally: .teal
        case .broken: .red
        }
    }

    var symbolName: String {
        switch self {
        case .unknown: "questionmark.circle"
        case .notInstalled: "circle.dashed"
        case .installed: "checkmark.circle.fill"
        case .installedExternally: "checkmark.circle"
        case .broken: "exclamationmark.triangle.fill"
        }
    }
}

extension RecipeCategory {
    var label: LocalizedStringKey {
        switch self {
        case .language: "Languages"
        case .runtime: "Runtimes"
        case .mobile: "Mobile"
        case .editor: "Editors"
        case .aiAgent: "AI Agents"
        case .custom: "Custom"
        }
    }

    var symbolName: String {
        switch self {
        case .language: "chevron.left.forwardslash.chevron.right"
        case .runtime: "gearshape.2"
        case .mobile: "iphone"
        case .editor: "square.and.pencil"
        case .aiAgent: "sparkles"
        case .custom: "puzzlepiece.extension"
        }
    }

    var tint: Color {
        switch self {
        case .language: .blue
        case .runtime: .purple
        case .mobile: .green
        case .editor: .orange
        case .aiAgent: .pink
        case .custom: .gray
        }
    }
}

struct RecipeIconTile: View {
    let category: RecipeCategory
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(category.tint.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: category.symbolName)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

struct StatusPill: View {
    let status: RecipeStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.symbolName)
            Text(status.pillLabel)
                .lineLimit(1)
                .fixedSize()
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(status.tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(status.tint.opacity(0.14), in: Capsule())
    }
}

extension RecipeAction: Identifiable {
    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .install: "Install"
        case .update: "Update"
        case .uninstall: "Uninstall"
        }
    }
}
