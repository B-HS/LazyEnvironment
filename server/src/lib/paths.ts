import { join } from 'node:path'

const SERVER_ROOT = join(import.meta.dir, '..', '..')

export const CATALOG_PATH = join(SERVER_ROOT, 'data', 'catalog.json')

export const MIGRATIONS_DIR = join(SERVER_ROOT, 'drizzle')
