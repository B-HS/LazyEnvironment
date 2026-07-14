import { afterAll, beforeAll, describe, expect, test } from 'bun:test'
import { createCatalogService } from '../src/service/domain/catalog/catalog.service'
import { createTestContext, readJson } from './test-helpers'
import type { ErrorEnvelope, SuccessEnvelope } from './test-helpers'

type CatalogData = Awaited<ReturnType<ReturnType<typeof createCatalogService>['getCatalog']>>

let context: Awaited<ReturnType<typeof createTestContext>>

beforeAll(async () => {
    context = await createTestContext()
})

afterAll(async () => {
    await context.cleanup()
})

describe('GET /api/catalog', () => {
    test('인증 없이 23개 레시피와 updatedAt 을 반환한다', async () => {
        const response = await context.app.request('/api/catalog')
        expect(response.status).toBe(200)
        const body = await readJson<SuccessEnvelope<CatalogData>>(response)
        expect(body.success).toBe(true)
        expect(Array.isArray(body.data.recipes)).toBe(true)
        expect(body.data.recipes.length).toBe(23)
        expect(typeof body.data.updatedAt).toBe('string')
        expect(new Date(body.data.updatedAt).toISOString()).toBe(body.data.updatedAt)
    })

    test('알 수 없는 경로는 NOT_FOUND 봉투를 반환한다', async () => {
        const response = await context.app.request('/api/does-not-exist')
        expect(response.status).toBe(404)
        const body = await readJson<ErrorEnvelope>(response)
        expect(body).toEqual({ success: false, error: { code: 'NOT_FOUND', message: expect.any(String) } })
    })
})
