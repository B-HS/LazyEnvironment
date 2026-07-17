import { createClient } from '@libsql/client'
import { drizzle } from 'drizzle-orm/libsql'
import { migrate } from 'drizzle-orm/libsql/migrator'
import { readMigrationFiles } from 'drizzle-orm/migrator'
import { getEnv } from '../src/lib/env'
import { MIGRATIONS_DIR } from '../src/lib/paths'

const TABLE_PREFIX = 'lazyenv_'
const JOURNAL_TABLE = 'lazyenv_drizzle_migrations'
const RESET_PREVIEW_LIMIT = 5
const EXPECTED_COLUMNS: Record<string, string[]> = {
    lazyenv_users: ['id', 'login', 'created_at'],
    lazyenv_environments: ['user_id', 'recipe_id', 'pinned_version', 'custom_path', 'enabled', 'updated_at'],
    lazyenv_custom_recipes: ['user_id', 'recipe_id', 'recipe_json', 'updated_at'],
}

const env = getEnv()
const credentials = { url: env.TURSO_DATABASE_URL, authToken: env.TURSO_AUTH_TOKEN }
const redact = (text: string) => {
    const masked = text.split(credentials.url).join('<db-url>')
    return credentials.authToken ? masked.split(credentials.authToken).join('<auth-token>') : masked
}

const client = createClient({ url: credentials.url, authToken: credentials.authToken })

const tableExists = async (name: string) => {
    const result = await client.execute({ sql: 'select name from sqlite_master where type = ? and name = ?', args: ['table', name] })
    return result.rows.length > 0
}

const rowCount = async (name: string) => {
    const result = await client.execute(`select count(*) as total from \`${name}\``)
    return Number(result.rows[0]?.total ?? 0)
}

const tableColumns = async (name: string) => {
    const result = await client.execute(`pragma table_info(\`${name}\`)`)
    return result.rows.map((row) => String(row.name)).sort()
}

const sameColumns = (left: string[], right: string[]) => left.length === right.length && left.every((value, index) => value === right[index])

const unknownNamespaceTables = async () => {
    const known = new Set([...Object.keys(EXPECTED_COLUMNS), JOURNAL_TABLE])
    const result = await client.execute({ sql: 'select name from sqlite_master where type = ? and name like ?', args: ['table', `${TABLE_PREFIX}%`] })
    return result.rows.map((row) => String(row.name)).filter((name) => !known.has(name))
}

const baselineJournal = async () => {
    await client.execute(`CREATE TABLE IF NOT EXISTS \`${JOURNAL_TABLE}\` (id SERIAL PRIMARY KEY, hash text NOT NULL, created_at numeric)`)
    for (const migration of readMigrationFiles({ migrationsFolder: MIGRATIONS_DIR })) {
        await client.execute({
            sql: `INSERT INTO \`${JOURNAL_TABLE}\` ("hash", "created_at") VALUES (?, ?)`,
            args: [migration.hash, migration.folderMillis],
        })
    }
}

const adoptLegacyNamespace = async () => {
    if (await tableExists(JOURNAL_TABLE)) return

    const unknown = await unknownNamespaceTables()
    if (unknown.length > 0) {
        console.error(`refusing to manage this database: unexpected ${TABLE_PREFIX}* tables exist (${unknown.join(', ')}) - resolve manually`)
        process.exit(1)
    }

    const names = Object.keys(EXPECTED_COLUMNS)
    const existing: string[] = []
    for (const name of names) {
        if (await tableExists(name)) existing.push(name)
    }
    if (existing.length === 0) return

    if (existing.length === names.length) {
        let allMatch = true
        for (const name of names) {
            if (!sameColumns(await tableColumns(name), [...EXPECTED_COLUMNS[name]].sort())) allMatch = false
        }
        if (allMatch) {
            await baselineJournal()
            console.log('adopted existing schema: journal baselined, data preserved')
            return
        }
    }

    const allowReset = env.MIGRATE_ALLOW_RESET === '1'
    for (const name of existing) {
        const total = await rowCount(name)
        if (total > 0 && !allowReset) {
            for (const diagnostic of existing) {
                console.error(`table ${diagnostic}: rows=${await rowCount(diagnostic)} columns=${(await tableColumns(diagnostic)).join(',')}`)
            }
            console.error(`refusing to reset: table ${name} has ${total} rows, no journal, and schema does not match - set MIGRATE_ALLOW_RESET=1 to discard`)
            process.exit(1)
        }
        if (total > 0) {
            const preview = await client.execute(`select * from \`${name}\` limit ${String(RESET_PREVIEW_LIMIT)}`)
            console.log(`discarding table ${name} (${total} rows): ${redact(JSON.stringify(preview.rows))}`)
        }
    }
    for (const name of existing) {
        await client.execute(`drop table \`${name}\``)
        console.log(`dropped unjournaled table ${name}`)
    }
}

console.log(`migrate target scheme=${credentials.url.split(':')[0]} urlLength=${credentials.url.length}`)
try {
    await adoptLegacyNamespace()
    await migrate(drizzle({ client }), { migrationsFolder: MIGRATIONS_DIR, migrationsTable: JOURNAL_TABLE })
    console.log('migrations applied')
} catch (error) {
    const message = error instanceof Error ? `${error.name}: ${error.message}` : String(error)
    console.error(`migration failed - ${redact(message)}`)
    process.exit(1)
}
