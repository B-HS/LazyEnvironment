import { Hono } from 'hono'
import { successResponse } from '../lib/api-response'
import { withErrorHandling } from '../lib/with-error-handling'
import type { CatalogService } from '../service/domain/catalog/catalog.service'

export const createCatalogRoute = (deps: { catalogService: CatalogService }) => {
    const route = new Hono()
    route.get(
        '/catalog',
        withErrorHandling(async (c) => {
            const catalog = await deps.catalogService.getCatalog()
            return c.json(successResponse({ recipes: catalog.recipes, updatedAt: catalog.updatedAt }))
        }),
    )
    return route
}
