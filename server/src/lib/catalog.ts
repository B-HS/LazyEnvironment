import { readFile, stat } from 'node:fs/promises'
import { CATALOG_PATH } from './paths'

export const loadCatalog = async () => {
    const [text, stats] = await Promise.all([readFile(CATALOG_PATH, 'utf8'), stat(CATALOG_PATH)])
    const recipes = JSON.parse(text) as Array<Record<string, unknown>>
    return { recipes, updatedAt: stats.mtime.toISOString() }
}
