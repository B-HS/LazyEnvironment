process.env['NODE_ENV'] = 'test'

import { describe, expect, test } from 'bun:test'
import { errorResponse, successResponse } from '../src/lib/api-response'

describe('응답 헬퍼', () => {
    test('successResponse 는 success:true 봉투로 감싼다', () => {
        expect(successResponse({ status: 'ok' })).toEqual({ success: true, data: { status: 'ok' } })
    })

    test('errorResponse 는 success:false 와 code·message 를 담는다', () => {
        expect(errorResponse('NOT_FOUND', '없음')).toEqual({ success: false, error: { code: 'NOT_FOUND', message: '없음' } })
    })

    test('비프로덕션에서는 details 를 노출한다', () => {
        const response = errorResponse('VALIDATION_ERROR', '검증 실패', { field: 'login' })
        expect(response.success).toBe(false)
        expect(response.error).toEqual({ code: 'VALIDATION_ERROR', message: '검증 실패', details: { field: 'login' } })
    })
})
