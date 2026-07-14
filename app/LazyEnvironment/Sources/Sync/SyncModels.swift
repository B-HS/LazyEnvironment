import Foundation

struct APIEnvelope<Payload: Decodable>: Decodable {
    let success: Bool
    let data: Payload?
    let error: APIError?
}

struct APIError: Decodable, Hashable {
    let code: String
    let message: String
}

struct CatalogPayload: Decodable {
    let recipes: [Recipe]
    let updatedAt: String?
}

struct HealthPayload: Decodable {
    let status: String
}

struct DevLoginPayload: Decodable {
    let token: String
    let login: String
}

struct SyncEnvironmentEntry: Codable, Hashable, Sendable {
    var recipeId: String
    var pinnedVersion: String?
    var customPath: String?
    var enabled: Bool?
    var updatedAt: String?
}

struct SyncCustomRecipeEntry: Codable, Hashable, Sendable {
    var recipeId: String
    var recipe: Recipe
    var updatedAt: String?
}

struct SyncProfilePayload: Codable, Sendable {
    var userId: String?
    var updatedAt: String?
    var environments: [SyncEnvironmentEntry]
    var customRecipes: [SyncCustomRecipeEntry]
}

struct SyncProfilePush: Encodable, Sendable {
    var environments: [SyncEnvironmentEntry]
    var customRecipes: [SyncCustomRecipeEntry]
}

enum SyncError: LocalizedError {
    case invalidServerURL
    case notSignedIn
    case requestFailed(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL: String(localized: "The sync server URL is invalid.")
        case .notSignedIn: String(localized: "Sign in before syncing.")
        case .requestFailed(let message): String(localized: "Sync request failed: \(message)")
        case .serverError(let message): String(localized: "Sync server error: \(message)")
        }
    }
}
