import { getDb } from '../db'
import { configureEnvironmentMode, getEnv } from '../lib/env'
import { composeAuth } from './auth'
import { composeCatalog } from './catalog'
import { composeProfile } from './profile'
import type { Database } from '../db'
import type { Env } from '../lib/env'

export type ComposeOverrides = {
    db?: Database
    env?: Env
}

export const compose = (overrides: ComposeOverrides = {}) => {
    const env = overrides.env ?? getEnv()
    configureEnvironmentMode(env.NODE_ENV)
    const db = overrides.db ?? getDb(env)
    return {
        env,
        db,
        ...composeCatalog(),
        ...composeProfile(db),
        ...composeAuth(db, env),
    }
}

export type Composed = ReturnType<typeof compose>
