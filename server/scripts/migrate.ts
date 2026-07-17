import { createClient } from '@libsql/client'
import { drizzle } from 'drizzle-orm/libsql'
import { migrate } from 'drizzle-orm/libsql/migrator'
import { getDbCredentials } from '../src/lib/env'
import { MIGRATIONS_DIR } from '../src/lib/paths'

const JOURNAL_TABLE = '__drizzle_migrations'
const SCHEMA_TABLES = ['users', 'environments', 'custom_recipes']

const credentials = getDbCredentials()
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

const adoptUnjournaledEmptySchema = async () => {
    if (await tableExists(JOURNAL_TABLE)) return
    const existing: string[] = []
    for (const table of SCHEMA_TABLES) {
        if (await tableExists(table)) existing.push(table)
    }
    if (existing.length === 0) return
    for (const table of existing) {
        const total = await rowCount(table)
        if (total > 0) {
            console.error(`refusing to reset: table ${table} has ${total} rows but no migration journal - resolve manually`)
            process.exit(1)
        }
    }
    for (const table of existing) {
        await client.execute(`drop table \`${table}\``)
        console.log(`dropped empty unjournaled table ${table}`)
    }
}

console.log(`migrate target scheme=${credentials.url.split(':')[0]} urlLength=${credentials.url.length}`)
try {
    await adoptUnjournaledEmptySchema()
    await migrate(drizzle({ client }), { migrationsFolder: MIGRATIONS_DIR })
    console.log('migrations applied')
} catch (error) {
    const message = error instanceof Error ? `${error.name}: ${error.message}` : String(error)
    console.error(`migration failed - ${redact(message)}`)
    process.exit(1)
}
