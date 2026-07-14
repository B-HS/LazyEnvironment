import { describe, expect, test } from 'bun:test'
import { createAppError, getStatusCode, isAppError } from '../src/lib/error'

describe('에러 헬퍼', () => {
    test('createAppError 는 코드·메시지·상태코드를 채운다', () => {
        const error = createAppError('NOT_FOUND')
        expect(error.code).toBe('NOT_FOUND')
        expect(error.statusCode).toBe(404)
        expect(typeof error.message).toBe('string')
        expect(error.message.length).toBeGreaterThan(0)
    })

    test('getStatusCode 는 코드별 HTTP 상태를 매핑한다', () => {
        expect(getStatusCode('UNAUTHORIZED')).toBe(401)
        expect(getStatusCode('FORBIDDEN')).toBe(403)
        expect(getStatusCode('VALIDATION_ERROR')).toBe(400)
        expect(getStatusCode('SERVICE_NOT_CONFIGURED')).toBe(503)
        expect(getStatusCode('INTERNAL_ERROR')).toBe(500)
        expect(getStatusCode('OAUTH_EXCHANGE_FAILED')).toBe(502)
    })

    test('createAppError 는 details 를 보존한다', () => {
        const error = createAppError('VALIDATION_ERROR', { field: 'login' })
        expect(error.details).toEqual({ field: 'login' })
    })

    test('isAppError 는 AppError 만 참으로 판별한다', () => {
        expect(isAppError(createAppError('INTERNAL_ERROR'))).toBe(true)
        expect(isAppError(new Error('boom'))).toBe(false)
        expect(isAppError(null)).toBe(false)
        expect(isAppError({ code: 'X' })).toBe(false)
        expect(isAppError({ code: 'X', message: 'm', statusCode: 400 })).toBe(true)
    })
})
