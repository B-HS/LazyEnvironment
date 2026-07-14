import { users } from '../db/schema'
import { signAuthToken } from '../lib/jwt'
import { createGetSession } from '../lib/session'
import { stub } from '../lib/stub'
import { createAuthService } from '../service/domain/auth/auth.service'
import { createGithubService } from '../service/shared/github/github.service'
import type { Database } from '../db'
import type { Env } from '../lib/env'
import type { GithubService } from '../service/shared/github/github.service'

export const composeAuth = (db: Database, env: Env) => {
    const clientId = env.GITHUB_CLIENT_ID
    const clientSecret = env.GITHUB_CLIENT_SECRET
    const github = stub<GithubService>(clientId && clientSecret ? createGithubService({ clientId, clientSecret }) : undefined)

    const authService = createAuthService({
        db: {
            upsertUser: async (user) => {
                await db
                    .insert(users)
                    .values({ id: user.id, login: user.login, createdAt: Date.now() })
                    .onConflictDoUpdate({ target: users.id, set: { login: user.login } })
            },
        },
        github,
        signToken: (payload) => signAuthToken(env.JWT_SECRET, payload),
    })

    return { authService, getSession: createGetSession(env.JWT_SECRET) }
}
