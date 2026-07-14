import { Hono } from 'hono'
import { createDevAuthRoute, createGithubAuthRoute } from './auth.route'
import { createCatalogRoute } from './catalog.route'
import { createHealthRoute } from './health.route'
import { createProfileRoute } from './profile.route'
import type { Composed } from '../compose'

export const createRouter = (composed: Composed) => {
    const api = new Hono()
    api.route('', createHealthRoute())
    api.route('', createCatalogRoute({ catalogService: composed.catalogService }))
    api.route('/auth', createDevAuthRoute({ authService: composed.authService, isDev: composed.env.NODE_ENV === 'development' }))
    api.route('/profile', createProfileRoute({ profileService: composed.profileService, getSession: composed.getSession }))

    const authWeb = createGithubAuthRoute({
        authService: composed.authService,
        callbackScheme: composed.env.APP_CALLBACK_SCHEME,
        cookieSecure: composed.env.NODE_ENV === 'production',
        serverBaseUrl: composed.env.SERVER_BASE_URL,
    })

    return { api, authWeb }
}
