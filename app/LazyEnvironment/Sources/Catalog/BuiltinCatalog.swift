import Foundation
import os

enum BuiltinCatalog {
    private static let logger = Logger(subsystem: "com.hyunseokbyun.LazyEnvironment", category: "BuiltinCatalog")

    static func load(bundle: Bundle = .main) -> [Recipe] {
        guard let url = bundle.url(forResource: "builtin-recipes", withExtension: "json") else {
            logger.error("builtin-recipes.json missing from bundle")
            return []
        }
        return load(from: url)
    }

    static func load(from url: URL) -> [Recipe] {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Recipe].self, from: data)
        } catch {
            logger.error("Failed to load builtin recipes: \(error.localizedDescription)")
            return []
        }
    }
}
