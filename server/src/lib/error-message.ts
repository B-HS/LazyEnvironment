import type { ErrorCode } from './error-code'

export const ERROR_MESSAGE: Record<ErrorCode, string> = {
    UNAUTHORIZED: 'Authentication is required.',
    FORBIDDEN: 'You do not have permission to perform this action.',
    NOT_FOUND: 'The requested resource was not found.',
    VALIDATION_ERROR: 'The request payload is invalid.',
    SERVICE_NOT_CONFIGURED: 'This service is not configured on the server.',
    INTERNAL_ERROR: 'An unexpected error occurred.',
    OAUTH_CODE_MISSING: 'The OAuth authorization code is missing.',
    OAUTH_STATE_MISMATCH: 'The OAuth state did not match. Please try signing in again.',
    OAUTH_EXCHANGE_FAILED: 'Failed to exchange the authorization code with GitHub.',
    OAUTH_PROFILE_FAILED: 'Failed to fetch the GitHub user profile.',
}
