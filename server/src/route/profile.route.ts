import { Hono } from 'hono'
import { profileUpdateSchema } from '../dto/profile.dto'
import { successResponse } from '../lib/api-response'
import { parseOrThrow } from '../lib/validation'
import { withAuth } from '../lib/with-auth'
import { withErrorHandling } from '../lib/with-error-handling'
import type { GetSession } from '../lib/with-auth'
import type { ProfileService } from '../service/domain/profile/profile.service'

export const createProfileRoute = (deps: { profileService: ProfileService; getSession: GetSession }) => {
    const route = new Hono()
    const guard = withAuth({ getSession: deps.getSession })

    route.get(
        '/',
        withErrorHandling(
            guard(async (c, user) => {
                const profile = await deps.profileService.get(user.id)
                return c.json(successResponse(profile))
            }),
        ),
    )

    route.put(
        '/',
        withErrorHandling(
            guard(async (c, user) => {
                const body = await c.req.json().catch(() => null)
                const input = parseOrThrow(profileUpdateSchema, body)
                const profile = await deps.profileService.replace(user.id, input)
                return c.json(successResponse(profile))
            }),
        ),
    )

    return route
}
