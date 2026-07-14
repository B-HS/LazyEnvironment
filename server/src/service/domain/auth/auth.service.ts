import { randomUUID } from 'node:crypto'
import type { GithubService } from '../../shared/github/github.service'

export type AuthServiceDb = {
    upsertUser: (user: { id: string; login: string }) => Promise<void>
}

export type AuthServiceDeps = {
    db: AuthServiceDb
    github: GithubService
    signToken: (payload: { sub: string; login: string }) => Promise<string>
}

export const createAuthService = (deps: AuthServiceDeps) => ({
    startGithubLogin: (redirectUri: string) => {
        const state = randomUUID()
        return { url: deps.github.buildAuthorizeUrl(redirectUri, state), state }
    },
    completeGithubLogin: async (code: string, redirectUri: string) => {
        const accessToken = await deps.github.exchangeCode(code, redirectUri)
        const githubUser = await deps.github.fetchUser(accessToken)
        await deps.db.upsertUser(githubUser)
        const token = await deps.signToken({ sub: githubUser.id, login: githubUser.login })
        return { token, login: githubUser.login }
    },
    devLogin: async (login: string) => {
        const user = { id: `dev_${login}`, login }
        await deps.db.upsertUser(user)
        const token = await deps.signToken({ sub: user.id, login: user.login })
        return { token, login: user.login }
    },
})

export type AuthService = ReturnType<typeof createAuthService>
