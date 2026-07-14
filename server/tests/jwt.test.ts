import { describe, expect, test } from 'bun:test'
import type { Context } from 'hono'
import { isAppError } from '../src/lib/error'
import { signAuthToken, verifyAuthToken } from '../src/lib/jwt'
import { createGetSession } from '../src/lib/session'
import { withAuth } from '../src/lib/with-auth'

const SECRET = 'jwt-round-trip-secret'

const fakeContext = (authorization?: string) =>
    ({ req: { header: (name: string) => (name === 'Authorization' ? authorization : undefined) } }) as unknown as Context

describe('JWT 서명·검증', () => {
    test('서명한 토큰을 다시 검증하면 sub·login 을 돌려준다', async () => {
        const token = await signAuthToken(SECRET, { sub: 'gh_1', login: 'octocat' })
        expect(await verifyAuthToken(SECRET, token)).toEqual({ sub: 'gh_1', login: 'octocat' })
    })

    test('다른 시크릿으로 검증하면 null 이다', async () => {
        const token = await signAuthToken(SECRET, { sub: 'gh_1', login: 'octocat' })
        expect(await verifyAuthToken('other-secret', token)).toBeNull()
    })

    test('변조된 토큰은 null 이다', async () => {
        const token = await signAuthToken(SECRET, { sub: 'gh_1', login: 'octocat' })
        expect(await verifyAuthToken(SECRET, `${token}tampered`)).toBeNull()
    })
})

describe('getSession + withAuth', () => {
    test('유효한 Bearer 헤더에서 유저를 복원한다', async () => {
        const token = await signAuthToken(SECRET, { sub: 'gh_2', login: 'monalisa' })
        const session = await createGetSession(SECRET)(fakeContext(`Bearer ${token}`))
        expect(session).toEqual({ user: { id: 'gh_2', login: 'monalisa' } })
    })

    test('헤더가 없거나 Bearer 가 아니면 null 이다', async () => {
        const getSession = createGetSession(SECRET)
        expect(await getSession(fakeContext(undefined))).toBeNull()
        expect(await getSession(fakeContext('token-without-bearer'))).toBeNull()
    })

    test('withAuth 는 세션이 없으면 UNAUTHORIZED 를 던진다', async () => {
        const guarded = withAuth({ getSession: createGetSession(SECRET) })((_c, user) => new Response(JSON.stringify(user)))
        let thrown: unknown
        try {
            await guarded(fakeContext(undefined))
        } catch (error) {
            thrown = error
        }
        expect(isAppError(thrown)).toBe(true)
        expect(isAppError(thrown) && thrown.code).toBe('UNAUTHORIZED')
    })

    test('withAuth 는 유효한 세션의 유저를 핸들러에 전달한다', async () => {
        const token = await signAuthToken(SECRET, { sub: 'gh_3', login: 'hubot' })
        const guarded = withAuth({ getSession: createGetSession(SECRET) })((_c, user) => new Response(JSON.stringify(user)))
        const response = await guarded(fakeContext(`Bearer ${token}`))
        expect(await response.json()).toEqual({ id: 'gh_3', login: 'hubot' })
    })
})
