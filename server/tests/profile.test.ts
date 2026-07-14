import { afterAll, beforeAll, describe, expect, test } from 'bun:test'
import { createProfileService } from '../src/service/domain/profile/profile.service'
import type { CustomRecipeRow, EnvironmentRow, ProfileService } from '../src/service/domain/profile/profile.service'
import type { AuthService } from '../src/service/domain/auth/auth.service'
import { createTestContext, readJson } from './test-helpers'
import type { ErrorEnvelope, SuccessEnvelope } from './test-helpers'

type DevAuthData = Awaited<ReturnType<AuthService['devLogin']>>
type ProfileData = Awaited<ReturnType<ProfileService['get']>>

let context: Awaited<ReturnType<typeof createTestContext>>

const devLogin = async (login: string) => {
    const response = await context.app.request('/api/auth/dev', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ login }),
    })
    const body = await readJson<SuccessEnvelope<DevAuthData>>(response)
    return body.data.token
}

const putProfile = (token: string, payload: unknown) =>
    context.app.request('/api/profile', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify(payload),
    })

const getProfile = (token: string) => context.app.request('/api/profile', { headers: { Authorization: `Bearer ${token}` } })

beforeAll(async () => {
    context = await createTestContext()
})

afterAll(async () => {
    await context.cleanup()
})

describe('개발용 인증 + 프로필 왕복', () => {
    test('/api/auth/dev 는 개발 환경에서 토큰을 발급한다', async () => {
        const response = await context.app.request('/api/auth/dev', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ login: 'octocat' }),
        })
        expect(response.status).toBe(200)
        const body = await readJson<SuccessEnvelope<DevAuthData>>(response)
        expect(body.success).toBe(true)
        expect(body.data.login).toBe('octocat')
        expect(typeof body.data.token).toBe('string')
    })

    test('인증 없이 접근하면 401 이다', async () => {
        const getResponse = await context.app.request('/api/profile')
        expect(getResponse.status).toBe(401)
        const putResponse = await context.app.request('/api/profile', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ environments: [], customRecipes: [] }),
        })
        expect(putResponse.status).toBe(401)
    })

    test('초기 프로필은 비어 있고 updatedAt 은 null 이다', async () => {
        const token = await devLogin('empty-user')
        const body = await readJson<SuccessEnvelope<ProfileData>>(await getProfile(token))
        expect(body.data.userId).toBe('dev_empty-user')
        expect(body.data.environments).toEqual([])
        expect(body.data.customRecipes).toEqual([])
        expect(body.data.updatedAt).toBeNull()
    })

    test('PUT 으로 저장하고 GET 으로 동일하게 읽는다', async () => {
        const token = await devLogin('round-trip')
        const payload = {
            environments: [
                { recipeId: 'node-nvm', pinnedVersion: '20.11.0', customPath: null, enabled: true },
                { recipeId: 'bun', enabled: false },
            ],
            customRecipes: [{ recipeId: 'my-tool', recipe: { id: 'my-tool', displayName: 'My Tool', category: 'custom' } }],
        }
        const putBody = await readJson<SuccessEnvelope<ProfileData>>(await putProfile(token, payload))
        expect(putBody.data.environments.length).toBe(2)
        const bun = putBody.data.environments.find((row) => row.recipeId === 'bun')
        expect(bun?.enabled).toBe(false)
        const node = putBody.data.environments.find((row) => row.recipeId === 'node-nvm')
        expect(node?.pinnedVersion).toBe('20.11.0')
        expect(typeof putBody.data.updatedAt).toBe('string')

        const getBody = await readJson<SuccessEnvelope<ProfileData>>(await getProfile(token))
        expect(getBody.data.environments).toEqual(putBody.data.environments)
        expect(getBody.data.customRecipes[0].recipe).toEqual({ id: 'my-tool', displayName: 'My Tool', category: 'custom' })
    })

    test('변경되지 않은 행의 updatedAt 은 재저장해도 보존된다 (LWW)', async () => {
        const token = await devLogin('preserve-user')
        const payload = {
            environments: [{ recipeId: 'node-nvm', pinnedVersion: '20.11.0', enabled: true }],
            customRecipes: [{ recipeId: 'my-tool', recipe: { id: 'my-tool', displayName: 'My Tool' } }],
        }
        const first = await readJson<SuccessEnvelope<ProfileData>>(await putProfile(token, payload))
        const firstEnvTs = first.data.environments[0].updatedAt
        const firstRecipeTs = first.data.customRecipes[0].updatedAt

        const second = await readJson<SuccessEnvelope<ProfileData>>(await putProfile(token, payload))
        expect(second.data.environments[0].updatedAt).toBe(firstEnvTs)
        expect(second.data.customRecipes[0].updatedAt).toBe(firstRecipeTs)
    })

    test('빠진 행은 삭제되고 남은 행만 유지된다 (replacement)', async () => {
        const token = await devLogin('replace-user')
        await putProfile(token, {
            environments: [
                { recipeId: 'node-nvm', enabled: true },
                { recipeId: 'bun', enabled: true },
            ],
            customRecipes: [{ recipeId: 'tool-a', recipe: { id: 'tool-a' } }],
        })
        await putProfile(token, {
            environments: [{ recipeId: 'node-nvm', enabled: true }],
            customRecipes: [],
        })
        const body = await readJson<SuccessEnvelope<ProfileData>>(await getProfile(token))
        expect(body.data.environments.map((row) => row.recipeId)).toEqual(['node-nvm'])
        expect(body.data.customRecipes).toEqual([])
    })
})

describe('운영 환경의 개발용 인증 게이팅', () => {
    test('production 에서는 /api/auth/dev 가 NOT_FOUND 이다', async () => {
        const prod = await createTestContext({ NODE_ENV: 'production' })
        const response = await prod.app.request('/api/auth/dev', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ login: 'octocat' }),
        })
        expect(response.status).toBe(404)
        const body = await readJson<ErrorEnvelope>(response)
        expect(body.error.code).toBe('NOT_FOUND')
        await prod.cleanup()
    })
})

describe('profileService LWW 타임스탬프 규칙 (주입된 시각)', () => {
    const makeFakeDb = () => {
        let environments: EnvironmentRow[] = []
        let customRecipes: CustomRecipeRow[] = []
        return {
            listEnvironments: async () => environments,
            listCustomRecipes: async () => customRecipes,
            replaceProfile: async (_userId: string, rows: EnvironmentRow[], recipeRows: CustomRecipeRow[]) => {
                environments = rows
                customRecipes = recipeRows
            },
        }
    }

    test('내용이 같으면 이전 시각을 유지하고, 바뀌면 새 시각을 찍는다', async () => {
        const service = createProfileService({ db: makeFakeDb() })
        const stableInput = { environments: [{ recipeId: 'a', enabled: true }], customRecipes: [] }

        await service.replace('u', stableInput, 1000)
        const preserved = await service.replace('u', stableInput, 2000)
        expect(preserved.environments[0].updatedAt).toBe(new Date(1000).toISOString())

        const changed = await service.replace('u', { environments: [{ recipeId: 'a', enabled: false }], customRecipes: [] }, 3000)
        expect(changed.environments[0].updatedAt).toBe(new Date(3000).toISOString())
    })
})
