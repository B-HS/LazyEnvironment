import Foundation

enum LatestVersionError: LocalizedError {
    case unsupportedPinning
    case requestFailed(String)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .unsupportedPinning: String(localized: "This recipe's source pinning does not provide a resolvable version.")
        case .requestFailed(let message): String(localized: "Version lookup failed: \(message)")
        case .malformedResponse: String(localized: "Version lookup returned an unexpected response.")
        }
    }
}

actor LatestVersionResolver {
    private var cache: [String: String] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func latestVersion(for pinning: SourcePinning) async throws -> String {
        switch pinning {
        case .pinned(let version):
            return version
        case .stableURL:
            throw LatestVersionError.unsupportedPinning
        case .githubLatestTag(let repo):
            return try await cached(key: "github:\(repo)") {
                try await self.fetchGitHubLatestTag(repo: repo)
            }
        case .goDevJSON:
            return try await cached(key: "go-dev") {
                try await self.fetchGoLatestVersion()
            }
        }
    }

    private func cached(key: String, fetch: () async throws -> String) async rethrows -> String {
        if let hit = cache[key] { return hit }
        let value = try await fetch()
        cache[key] = value
        return value
    }

    private func fetchGitHubLatestTag(repo: String) async throws -> String {
        struct Release: Decodable {
            let tagName: String

            private enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
            }
        }
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            throw LatestVersionError.requestFailed(repo)
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("lazy-environment", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LatestVersionError.requestFailed(url.absoluteString)
        }
        guard let release = try? JSONDecoder().decode(Release.self, from: data) else {
            throw LatestVersionError.malformedResponse
        }
        return release.tagName
    }

    private func fetchGoLatestVersion() async throws -> String {
        struct GoRelease: Decodable {
            let version: String
        }
        guard let url = URL(string: "https://go.dev/dl/?mode=json") else {
            throw LatestVersionError.requestFailed("go.dev")
        }
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LatestVersionError.requestFailed(url.absoluteString)
        }
        guard let releases = try? JSONDecoder().decode([GoRelease].self, from: data), let first = releases.first else {
            throw LatestVersionError.malformedResponse
        }
        return first.version
    }
}
