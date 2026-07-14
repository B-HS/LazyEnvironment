import { createClient } from '@libsql/client'
import { drizzle } from 'drizzle-orm/libsql'
import { getEnv } from '../lib/env'
import * as schema from './schema'
import type { Env } from '../lib/env'

const createDb = (env: Env) => {
    const client = createClient({ url: env.TURSO_DATABASE_URL, authToken: env.TURSO_AUTH_TOKEN })
    return drizzle({ client, schema })
}

let dbInstance: ReturnType<typeof createDb> | null = null

export const getDb = (env: Env = getEnv()) => (dbInstance ??= createDb(env))

export type Database = ReturnType<typeof createDb>
