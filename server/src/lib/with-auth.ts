import { createAppError } from './error'
import type { Context } from 'hono'

export type SessionUser = { id: string; login: string }

export type GetSession = (c: Context) => Promise<{ user: SessionUser } | null>

type AuthHandler = (c: Context, user: SessionUser) => Response | Promise<Response>

export const withAuth = (deps: { getSession: GetSession }) => (handler: AuthHandler) => async (c: Context) => {
    const session = await deps.getSession(c)
    if (!session) throw createAppError('UNAUTHORIZED')
    return handler(c, session.user)
}
