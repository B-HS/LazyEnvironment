import { Hono } from 'hono'
import { renderError } from './lib/api-response'
import { createAppError } from './lib/error'
import { applyMiddleware } from './middleware'
import { createRouter } from './route'
import type { Composed } from './compose'

export const createApp = (composed: Composed) => {
    const app = new Hono()
    applyMiddleware(app)

    const { api, authWeb } = createRouter(composed)
    app.route('/auth', authWeb)
    app.route('/api', api)

    app.notFound((c) => renderError(c, createAppError('NOT_FOUND')))
    app.onError((error, c) => renderError(c, error))

    return app
}
