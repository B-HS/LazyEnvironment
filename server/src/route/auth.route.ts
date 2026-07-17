import { Hono } from 'hono'
import { deleteCookie, getCookie, setCookie } from 'hono/cookie'
import { devAuthSchema } from '../dto/auth.dto'
import { successResponse } from '../lib/api-response'
import { createAppError, isAppError } from '../lib/error'
import { parseOrThrow } from '../lib/validation'
import { withErrorHandling } from '../lib/with-error-handling'
import type { AuthService } from '../service/domain/auth/auth.service'

const OAUTH_STATE_COOKIE = 'oauth_state'
const OAUTH_STATE_MAX_AGE = 600

const resolveCallbackUri = (requestUrl: string, serverBaseUrl?: string) => {
    const origin = (serverBaseUrl ?? new URL(requestUrl).origin).replace(/\/+$/, '')
    return `${origin}/auth/github/callback`
}

export const createGithubAuthRoute = (deps: { authService: AuthService; callbackScheme: string; cookieSecure: boolean; serverBaseUrl?: string }) => {
    const route = new Hono()

    route.get(
        '/github',
        withErrorHandling((c) => {
            const { url, state } = deps.authService.startGithubLogin(resolveCallbackUri(c.req.url, deps.serverBaseUrl))
            setCookie(c, OAUTH_STATE_COOKIE, state, {
                httpOnly: true,
                secure: deps.cookieSecure,
                sameSite: 'Lax',
                path: '/',
                maxAge: OAUTH_STATE_MAX_AGE,
            })
            return c.redirect(url, 302)
        }),
    )

    route.get(
        '/github/callback',
        withErrorHandling(async (c) => {
            const failureRedirect = (code: string) => c.redirect(`${deps.callbackScheme}://auth#error=${encodeURIComponent(code)}`, 302)
            const code = c.req.query('code')
            const state = c.req.query('state')
            const cookieState = getCookie(c, OAUTH_STATE_COOKIE)
            deleteCookie(c, OAUTH_STATE_COOKIE, { path: '/' })
            try {
                if (!code) return failureRedirect('OAUTH_CODE_MISSING')
                if (!state || !cookieState || state !== cookieState) return failureRedirect('OAUTH_STATE_MISMATCH')
                const { token, login } = await deps.authService.completeGithubLogin(code, resolveCallbackUri(c.req.url, deps.serverBaseUrl))
                return c.redirect(`${deps.callbackScheme}://auth#token=${encodeURIComponent(token)}&login=${encodeURIComponent(login)}`, 302)
            } catch (error) {
                if (isAppError(error)) return failureRedirect(error.code)
                return failureRedirect(`INTERNAL_ERROR_${error instanceof Error ? error.name : 'UNKNOWN'}`)
            }
        }),
    )

    return route
}

export const createDevAuthRoute = (deps: { authService: AuthService; isDev: boolean }) => {
    const route = new Hono()
    route.post(
        '/dev',
        withErrorHandling(async (c) => {
            if (!deps.isDev) throw createAppError('NOT_FOUND')
            const body = await c.req.json().catch(() => null)
            const input = parseOrThrow(devAuthSchema, body)
            const result = await deps.authService.devLogin(input.login)
            return c.json(successResponse(result))
        }),
    )
    return route
}
