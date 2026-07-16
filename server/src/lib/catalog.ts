import { readFile, stat } from 'node:fs/promises'
import bundledCatalog from '../../data/catalog.json'
import { CATALOG_PATH } from './paths'

const bundledCatalogLoadedAt = new Date().toISOString()

export const loadCatalog = async () => {
    try {
        const [text, stats] = await Promise.all([readFile(CATALOG_PATH, 'utf8'), stat(CATALOG_PATH)])
        const recipes = JSON.parse(text) as Array<Record<string, unknown>>
        return { recipes, updatedAt: stats.mtime.toISOString() }
    } catch {
        return { recipes: bundledCatalog as Array<Record<string, unknown>>, updatedAt: bundledCatalogLoadedAt }
    }
}
