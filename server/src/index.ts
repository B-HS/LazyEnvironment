import { migrate } from 'drizzle-orm/libsql/migrator'
import { createApp } from './app'
import { compose } from './compose'
import { MIGRATIONS_DIR } from './lib/paths'

const composed = compose()

await migrate(composed.db, { migrationsFolder: MIGRATIONS_DIR })

const app = createApp(composed)

Bun.serve({ port: composed.env.PORT, fetch: app.fetch })

console.log(`lazy-environment server listening on http://localhost:${composed.env.PORT}`)
