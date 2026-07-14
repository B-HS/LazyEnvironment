import { z } from 'zod'

const optionalString = z.preprocess((value) => (typeof value === 'string' && value.trim() === '' ? undefined : value), z.string().min(1).optional())

const envSchema = z.object({
    TURSO_DATABASE_URL: z.string().min(1).default('file:local.db'),
    TURSO_AUTH_TOKEN: optionalString,
    JWT_SECRET: z.string().min(1),
    GITHUB_CLIENT_ID: optionalString,
    GITHUB_CLIENT_SECRET: optionalString,
    PORT: z.coerce.number().int().positive().default(25252),
    NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
    APP_CALLBACK_SCHEME: z.string().min(1).default('lazyenvironment'),
    SERVER_BASE_URL: optionalString,
})

export type Env = z.infer<typeof envSchema>

export const parseEnv = (source: Record<string, string | undefined>) => envSchema.parse(source)

let cachedEnv: Env | null = null

export const getEnv = () => (cachedEnv ??= parseEnv(process.env))

let productionModeOverride: boolean | null = null

export const configureEnvironmentMode = (nodeEnv: Env['NODE_ENV']) => {
    productionModeOverride = nodeEnv === 'production'
}

export const isProductionEnv = () => {
    if (productionModeOverride !== null) return productionModeOverride
    const { NODE_ENV } = process.env
    return NODE_ENV === 'production'
}

const dbCredentialsSchema = z.object({
    TURSO_DATABASE_URL: z.string().min(1).default('file:local.db'),
    TURSO_AUTH_TOKEN: optionalString,
})

export const getDbCredentials = () => {
    const parsed = dbCredentialsSchema.safeParse(process.env)
    const data = parsed.success ? parsed.data : { TURSO_DATABASE_URL: 'file:local.db', TURSO_AUTH_TOKEN: undefined }
    return { url: data.TURSO_DATABASE_URL, authToken: data.TURSO_AUTH_TOKEN }
}
