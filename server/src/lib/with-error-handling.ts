import { renderError } from './api-response'
import type { Context } from 'hono'

type Handler = (c: Context) => Response | Promise<Response>

export const withErrorHandling = (handler: Handler) => async (c: Context) => {
    try {
        return await handler(c)
    } catch (error) {
        return renderError(c, error)
    }
}
