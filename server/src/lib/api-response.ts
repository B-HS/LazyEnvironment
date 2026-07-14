import { isProductionEnv } from './env'
import { isAppError, createAppError } from './error'
import type { Context } from 'hono'

export const successResponse = <T>(data: T) => ({ success: true as const, data })

export const errorResponse = (code: string, message: string, details?: Record<string, unknown>) => ({
    success: false as const,
    error: details && !isProductionEnv() ? { code, message, details } : { code, message },
})

export const renderError = (c: Context, error: unknown) => {
    const appError = isAppError(error) ? error : createAppError('INTERNAL_ERROR')
    return c.json(errorResponse(appError.code, appError.message, appError.details), appError.statusCode as 400)
}
