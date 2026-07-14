import { verifyAuthToken } from './jwt'
import type { GetSession } from './with-auth'

const BEARER_PREFIX = 'Bearer '

export const createGetSession =
    (secret: string): GetSession =>
    async (c) => {
        const header = c.req.header('Authorization') ?? ''
        if (!header.startsWith(BEARER_PREFIX)) return null
        const payload = await verifyAuthToken(secret, header.slice(BEARER_PREFIX.length))
        if (!payload) return null
        return { user: { id: payload.sub, login: payload.login } }
    }
