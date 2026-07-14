import { sign, verify } from 'hono/jwt'

const THIRTY_DAYS_IN_SECONDS = 60 * 60 * 24 * 30
const JWT_ALGORITHM = 'HS256'

export type AuthTokenPayload = { sub: string; login: string }

export const signAuthToken = (secret: string, payload: AuthTokenPayload) =>
    sign({ sub: payload.sub, login: payload.login, exp: Math.floor(Date.now() / 1000) + THIRTY_DAYS_IN_SECONDS }, secret, JWT_ALGORITHM)

export const verifyAuthToken = async (secret: string, token: string): Promise<AuthTokenPayload | null> => {
    try {
        const claims = (await verify(token, secret, JWT_ALGORITHM)) as Record<string, unknown>
        const sub = claims.sub
        const login = claims.login
        if (typeof sub !== 'string' || typeof login !== 'string') return null
        return { sub, login }
    } catch {
        return null
    }
}
