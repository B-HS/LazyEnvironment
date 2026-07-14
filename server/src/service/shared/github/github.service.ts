import { createAppError } from '../../../lib/error'

const GITHUB_AUTHORIZE_URL = 'https://github.com/login/oauth/authorize'
const GITHUB_TOKEN_URL = 'https://github.com/login/oauth/access_token'
const GITHUB_USER_URL = 'https://api.github.com/user'

export type GithubServiceDeps = {
    clientId: string
    clientSecret: string
}

export const createGithubService = (deps: GithubServiceDeps) => ({
    buildAuthorizeUrl: (redirectUri: string, state: string) => {
        const params = new URLSearchParams({ client_id: deps.clientId, redirect_uri: redirectUri, state, scope: 'read:user' })
        return `${GITHUB_AUTHORIZE_URL}?${params.toString()}`
    },
    exchangeCode: async (code: string, redirectUri: string) => {
        const response = await fetch(GITHUB_TOKEN_URL, {
            method: 'POST',
            headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
            body: JSON.stringify({ client_id: deps.clientId, client_secret: deps.clientSecret, code, redirect_uri: redirectUri }),
        })
        if (!response.ok) throw createAppError('OAUTH_EXCHANGE_FAILED', { status: response.status })
        const payload = (await response.json()) as { access_token?: string; error?: string }
        if (!payload.access_token) throw createAppError('OAUTH_EXCHANGE_FAILED', payload.error ? { error: payload.error } : undefined)
        return payload.access_token
    },
    fetchUser: async (accessToken: string) => {
        const response = await fetch(GITHUB_USER_URL, {
            headers: { Accept: 'application/vnd.github+json', Authorization: `Bearer ${accessToken}`, 'User-Agent': 'lazy-environment-server' },
        })
        if (!response.ok) throw createAppError('OAUTH_PROFILE_FAILED', { status: response.status })
        const payload = (await response.json()) as { id?: number; login?: string }
        if (typeof payload.id !== 'number' || typeof payload.login !== 'string') throw createAppError('OAUTH_PROFILE_FAILED')
        return { id: String(payload.id), login: payload.login }
    },
})

export type GithubService = ReturnType<typeof createGithubService>
