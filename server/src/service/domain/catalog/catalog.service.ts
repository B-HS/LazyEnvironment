export type CatalogServiceDeps = {
    readCatalog: () => Promise<{ recipes: Array<Record<string, unknown>>; updatedAt: string }>
}

export const createCatalogService = (deps: CatalogServiceDeps) => ({
    getCatalog: () => deps.readCatalog(),
})

export type CatalogService = ReturnType<typeof createCatalogService>
