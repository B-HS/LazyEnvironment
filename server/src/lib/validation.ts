import { z } from 'zod'
import { createAppError } from './error'

export const parseOrThrow = <T extends z.ZodType>(schema: T, data: unknown): z.infer<T> => {
    const result = schema.safeParse(data)
    if (!result.success) throw createAppError('VALIDATION_ERROR', { issues: result.error.issues })
    return result.data
}
