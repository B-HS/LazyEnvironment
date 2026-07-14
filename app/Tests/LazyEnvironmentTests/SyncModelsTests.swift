import Foundation
import Testing
@testable import LazyEnvironment

struct SyncModelsTests {
    private let profileFixture = """
    {"success":true,"data":{"userId":"dev_e2e-user","updatedAt":"2026-07-14T05:23:35.135Z","environments":[{"recipeId":"go","pinnedVersion":"go1.24.1","customPath":null,"enabled":true,"updatedAt":"2026-07-14T05:23:35.135Z"},{"recipeId":"rustup","pinnedVersion":null,"customPath":"/Volumes/Dev/rust","enabled":true,"updatedAt":"2026-07-14T05:23:35.135Z"}],"customRecipes":[{"recipeId":"my-tool","recipe":{"category":"custom","detectCommand":"true","displayName":"My Tool","id":"my-tool"},"updatedAt":"2026-07-14T05:23:35.135Z"}]}}
    """

    private let errorFixture = """
    {"success":false,"error":{"code":"UNAUTHORIZED","message":"Authentication required."}}
    """

    @Test
    func decodesLiveProfileEnvelope() throws {
        let envelope = try JSONDecoder().decode(APIEnvelope<SyncProfilePayload>.self, from: Data(profileFixture.utf8))
        #expect(envelope.success)
        let profile = try #require(envelope.data)
        #expect(profile.userId == "dev_e2e-user")
        #expect(profile.environments.count == 2)
        #expect(profile.environments[0].pinnedVersion == "go1.24.1")
        #expect(profile.environments[1].customPath == "/Volumes/Dev/rust")
        #expect(profile.customRecipes.first?.recipe.id == "my-tool")
        #expect(profile.customRecipes.first?.recipe.category == .custom)
    }

    @Test
    func decodesErrorEnvelope() throws {
        let envelope = try JSONDecoder().decode(APIEnvelope<SyncProfilePayload>.self, from: Data(errorFixture.utf8))
        #expect(envelope.success == false)
        #expect(envelope.data == nil)
        #expect(envelope.error?.code == "UNAUTHORIZED")
    }

    @Test
    func encodesProfilePushWithNullableFields() throws {
        let push = SyncProfilePush(
            environments: [
                SyncEnvironmentEntry(recipeId: "go", pinnedVersion: "go1.24.1", customPath: nil, enabled: true, updatedAt: nil)
            ],
            customRecipes: []
        )
        let data = try JSONEncoder().encode(push)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let environments = decoded?["environments"] as? [[String: Any]]
        #expect(environments?.first?["recipeId"] as? String == "go")
        #expect(environments?.first?["pinnedVersion"] as? String == "go1.24.1")
    }
}
