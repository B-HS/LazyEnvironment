import { cors } from 'hono/cors'
import { secureHeaders } from 'hono/secure-headers'
import type { Hono } from 'hono'

export const applyMiddleware = (app: Hono) => {
    app.use('*', secureHeaders())
    app.use('/api/*', cors())
}
