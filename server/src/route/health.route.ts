import { Hono } from 'hono'
import { successResponse } from '../lib/api-response'
import { withErrorHandling } from '../lib/with-error-handling'

export const createHealthRoute = () => {
    const route = new Hono()
    route.get(
        '/health',
        withErrorHandling((c) => c.json(successResponse({ status: 'ok' }))),
    )
    return route
}
