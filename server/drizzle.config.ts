import { defineConfig } from 'drizzle-kit'
import { getDbCredentials } from './src/lib/env'

export default defineConfig({
    dialect: 'turso',
    schema: './src/db/schema.ts',
    out: './drizzle',
    dbCredentials: getDbCredentials(),
})
