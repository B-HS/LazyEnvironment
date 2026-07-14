import { loadCatalog } from '../lib/catalog'
import { createCatalogService } from '../service/domain/catalog/catalog.service'

export const composeCatalog = () => ({
    catalogService: createCatalogService({ readCatalog: loadCatalog }),
})
