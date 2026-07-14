import { createClient } from '@libsql/client'
import { drizzle } from 'drizzle-orm/libsql'
import { migrate } from 'drizzle-orm/libsql/migrator'
import { rm } from 'node:fs/promises'
import { createApp } from '../src/app'
import { compose } from '../src/compose'
import * as schema from '../src/db/schema'
import { parseEnv } from '../src/lib/env'
import { MIGRATIONS_DIR } from '../src/lib/paths'

export const createTestContext = async (overrides: Record<string, string | undefined> = {}) => {
    const dbFile = `test-${crypto.randomUUID()}.db`
    const url = `file:${dbFile}`
    const env = parseEnv({
        JWT_SECRET: 'test-secret',
        TURSO_DATABASE_URL: url,
        NODE_ENV: 'development',
        APP_CALLBACK_SCHEME: 'lazyenvironment',
        ...overrides,
    })
    const client = createClient({ url })
    const db = drizzle({ client, schema })
    await migrate(db, { migrationsFolder: MIGRATIONS_DIR })
    const composed = compose({ db, env })
    const app = createApp(composed)

    const cleanup = async () => {
        client.close()
        await Promise.all([`${dbFile}`, `${dbFile}-journal`, `${dbFile}-wal`, `${dbFile}-shm`].map((path) => rm(path, { force: true })))
    }

    return { app, env, db, composed, cleanup }
}

export type SuccessEnvelope<T> = { success: true; data: T }

export type ErrorEnvelope = { success: false; error: { code: string; message: string } }

export const readJson = <T>(response: Response) => response.json() as Promise<T>
