import Foundation

struct SyncClient: Sendable {
    let baseURL: URL
    let token: String?
    private let session: URLSession

    init(baseURL: URL, token: String?, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    func fetchHealth() async throws -> HealthPayload {
        try await request(path: "/api/health", method: "GET", body: Optional<Int>.none)
    }

    func fetchCatalog() async throws -> CatalogPayload {
        try await request(path: "/api/catalog", method: "GET", body: Optional<Int>.none)
    }

    func devLogin(login: String) async throws -> DevLoginPayload {
        try await request(path: "/api/auth/dev", method: "POST", body: ["login": login])
    }

    func fetchProfile() async throws -> SyncProfilePayload {
        try await request(path: "/api/profile", method: "GET", body: Optional<Int>.none)
    }

    func pushProfile(_ push: SyncProfilePush) async throws -> SyncProfilePayload {
        try await request(path: "/api/profile", method: "PUT", body: push)
    }

    private func request<Body: Encodable, Payload: Decodable>(
        path: String,
        method: String,
        body: Body?
    ) async throws -> Payload {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw SyncError.invalidServerURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SyncError.requestFailed(error.localizedDescription)
        }
        guard response is HTTPURLResponse else {
            throw SyncError.requestFailed(url.absoluteString)
        }
        let envelope: APIEnvelope<Payload>
        do {
            envelope = try JSONDecoder().decode(APIEnvelope<Payload>.self, from: data)
        } catch {
            throw SyncError.serverError(String(localized: "Unexpected response from the sync server."))
        }
        if let payload = envelope.data, envelope.success {
            return payload
        }
        throw SyncError.serverError(envelope.error?.message ?? String(localized: "Unknown server error."))
    }
}
