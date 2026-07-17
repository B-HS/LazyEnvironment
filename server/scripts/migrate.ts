import { createClient } from '@libsql/client'
import { drizzle } from 'drizzle-orm/libsql'
import { migrate } from 'drizzle-orm/libsql/migrator'
import { getDbCredentials } from '../src/lib/env'
import { MIGRATIONS_DIR } from '../src/lib/paths'

const credentials = getDbCredentials()
const redact = (text: string) => {
    const masked = text.split(credentials.url).join('<db-url>')
    return credentials.authToken ? masked.split(credentials.authToken).join('<auth-token>') : masked
}

console.log(`migrate target scheme=${credentials.url.split(':')[0]} urlLength=${credentials.url.length}`)
try {
    const db = drizzle({ client: createClient({ url: credentials.url, authToken: credentials.authToken }) })
    await migrate(db, { migrationsFolder: MIGRATIONS_DIR })
    console.log('migrations applied')
} catch (error) {
    const message = error instanceof Error ? `${error.name}: ${error.message}` : String(error)
    console.error(`migration failed - ${redact(message)}`)
    process.exit(1)
}
