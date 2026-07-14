import { describe, expect, test } from 'bun:test'
import { devAuthSchema } from '../src/dto/auth.dto'
import { profileUpdateSchema } from '../src/dto/profile.dto'

describe('devAuthSchema', () => {
    test('유효한 login 을 통과시킨다', () => {
        expect(devAuthSchema.safeParse({ login: 'octo-cat_1.2' }).success).toBe(true)
    })

    test('빈 login 은 실패한다', () => {
        expect(devAuthSchema.safeParse({ login: '' }).success).toBe(false)
    })

    test('허용되지 않은 문자는 실패한다', () => {
        expect(devAuthSchema.safeParse({ login: 'bad login!' }).success).toBe(false)
    })
})

describe('profileUpdateSchema', () => {
    test('유효한 페이로드를 통과시킨다', () => {
        const result = profileUpdateSchema.safeParse({
            environments: [{ recipeId: 'node-nvm', pinnedVersion: null, customPath: null, enabled: true }],
            customRecipes: [{ recipeId: 'my-tool', recipe: { id: 'my-tool', displayName: 'My Tool' } }],
        })
        expect(result.success).toBe(true)
    })

    test('environments 의 중복 recipeId 는 실패한다', () => {
        const result = profileUpdateSchema.safeParse({
            environments: [{ recipeId: 'node-nvm' }, { recipeId: 'node-nvm' }],
            customRecipes: [],
        })
        expect(result.success).toBe(false)
    })

    test('environments 키가 없으면 실패한다', () => {
        expect(profileUpdateSchema.safeParse({ customRecipes: [] }).success).toBe(false)
    })

    test('recipe 가 객체가 아니면 실패한다', () => {
        const result = profileUpdateSchema.safeParse({
            environments: [],
            customRecipes: [{ recipeId: 'x', recipe: 'not-an-object' }],
        })
        expect(result.success).toBe(false)
    })
})
