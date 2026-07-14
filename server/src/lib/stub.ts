import { createAppError } from './error'

export const stub = <T>(value: T | undefined): T =>
    value ??
    (new Proxy(
        {},
        {
            get: () => () => {
                throw createAppError('SERVICE_NOT_CONFIGURED')
            },
        },
    ) as T)
