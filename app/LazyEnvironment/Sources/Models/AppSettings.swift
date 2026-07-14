import Foundation

enum LanguageOption: String, Codable, CaseIterable, Sendable, Identifiable {
    case system
    case korean = "ko"
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }

    var locale: Locale? {
        switch self {
        case .system: nil
        case .korean: Locale(identifier: "ko")
        case .english: Locale(identifier: "en")
        case .japanese: Locale(identifier: "ja")
        }
    }
}

enum SyncMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case online
    case offline

    var id: String { rawValue }
}

struct AppSettings: Codable, Sendable, Hashable {
    var devHome: String
    var language: LanguageOption
    var confirmBeforeEveryRun: Bool
    var menuBarEnabled: Bool
    var startInMenuBar: Bool
    var syncServerURL: String
    var syncMode: SyncMode

    static let `default` = AppSettings(
        devHome: "~/development",
        language: .system,
        confirmBeforeEveryRun: false,
        menuBarEnabled: true,
        startInMenuBar: false,
        syncServerURL: "http://127.0.0.1:25252",
        syncMode: .online
    )

    init(
        devHome: String,
        language: LanguageOption,
        confirmBeforeEveryRun: Bool,
        menuBarEnabled: Bool,
        startInMenuBar: Bool,
        syncServerURL: String,
        syncMode: SyncMode
    ) {
        self.devHome = devHome
        self.language = language
        self.confirmBeforeEveryRun = confirmBeforeEveryRun
        self.menuBarEnabled = menuBarEnabled
        self.startInMenuBar = startInMenuBar
        self.syncServerURL = syncServerURL
        self.syncMode = syncMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings.default
        devHome = try container.decodeIfPresent(String.self, forKey: .devHome) ?? fallback.devHome
        language = try container.decodeIfPresent(LanguageOption.self, forKey: .language) ?? fallback.language
        confirmBeforeEveryRun = try container.decodeIfPresent(Bool.self, forKey: .confirmBeforeEveryRun) ?? fallback.confirmBeforeEveryRun
        menuBarEnabled = try container.decodeIfPresent(Bool.self, forKey: .menuBarEnabled) ?? fallback.menuBarEnabled
        startInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .startInMenuBar) ?? fallback.startInMenuBar
        syncServerURL = try container.decodeIfPresent(String.self, forKey: .syncServerURL) ?? fallback.syncServerURL
        syncMode = try container.decodeIfPresent(SyncMode.self, forKey: .syncMode) ?? fallback.syncMode
    }
}
