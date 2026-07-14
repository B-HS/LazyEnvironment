import { ERROR_MESSAGE } from './error-message'
import type { ErrorCode } from './error-code'

export type AppError = {
    code: ErrorCode
    message: string
    statusCode: number
    details?: Record<string, unknown>
}

const STATUS_MAP: Record<ErrorCode, number> = {
    UNAUTHORIZED: 401,
    FORBIDDEN: 403,
    NOT_FOUND: 404,
    VALIDATION_ERROR: 400,
    SERVICE_NOT_CONFIGURED: 503,
    INTERNAL_ERROR: 500,
    OAUTH_CODE_MISSING: 400,
    OAUTH_STATE_MISMATCH: 400,
    OAUTH_EXCHANGE_FAILED: 502,
    OAUTH_PROFILE_FAILED: 502,
}

export const getStatusCode = (code: ErrorCode) => STATUS_MAP[code]

export const createAppError = (code: ErrorCode, details?: Record<string, unknown>): AppError => ({
    code,
    message: ERROR_MESSAGE[code],
    statusCode: getStatusCode(code),
    details,
})

export const isAppError = (error: unknown): error is AppError =>
    typeof error === 'object' && error !== null && 'code' in error && 'message' in error && 'statusCode' in error
