import { stableStringify } from '../../../lib/json'
import type { ProfileUpdateInput } from '../../../dto/profile.dto'

export type EnvironmentRow = {
    recipeId: string
    pinnedVersion: string | null
    customPath: string | null
    enabled: boolean
    updatedAt: number
}

export type CustomRecipeRow = {
    recipeId: string
    recipeJson: string
    updatedAt: number
}

export type ProfileServiceDb = {
    listEnvironments: (userId: string) => Promise<EnvironmentRow[]>
    listCustomRecipes: (userId: string) => Promise<CustomRecipeRow[]>
    replaceProfile: (userId: string, environments: EnvironmentRow[], customRecipes: CustomRecipeRow[]) => Promise<void>
}

export type ProfileServiceDeps = {
    db: ProfileServiceDb
}

const toIso = (ms: number) => new Date(ms).toISOString()

const byRecipeId = (a: { recipeId: string }, b: { recipeId: string }) => a.recipeId.localeCompare(b.recipeId)

const buildProfile = (userId: string, environments: EnvironmentRow[], customRecipes: CustomRecipeRow[]) => {
    const timestamps = [...environments.map((row) => row.updatedAt), ...customRecipes.map((row) => row.updatedAt)]
    const maxUpdatedAt = timestamps.length > 0 ? Math.max(...timestamps) : null
    return {
        userId,
        updatedAt: maxUpdatedAt === null ? null : toIso(maxUpdatedAt),
        environments: environments
            .slice()
            .sort(byRecipeId)
            .map((row) => ({
                recipeId: row.recipeId,
                pinnedVersion: row.pinnedVersion,
                customPath: row.customPath,
                enabled: row.enabled,
                updatedAt: toIso(row.updatedAt),
            })),
        customRecipes: customRecipes
            .slice()
            .sort(byRecipeId)
            .map((row) => ({
                recipeId: row.recipeId,
                recipe: JSON.parse(row.recipeJson) as Record<string, unknown>,
                updatedAt: toIso(row.updatedAt),
            })),
    }
}

export const createProfileService = (deps: ProfileServiceDeps) => {
    const get = async (userId: string) => {
        const [environments, customRecipes] = await Promise.all([deps.db.listEnvironments(userId), deps.db.listCustomRecipes(userId)])
        return buildProfile(userId, environments, customRecipes)
    }

    const replace = async (userId: string, input: ProfileUpdateInput, now: number = Date.now()) => {
        const [existingEnvironments, existingCustomRecipes] = await Promise.all([deps.db.listEnvironments(userId), deps.db.listCustomRecipes(userId)])

        const nextEnvironments: EnvironmentRow[] = input.environments.map((item) => {
            const previous = existingEnvironments.find((row) => row.recipeId === item.recipeId)
            const pinnedVersion = item.pinnedVersion ?? null
            const customPath = item.customPath ?? null
            const enabled = item.enabled ?? true
            const changed =
                !previous || previous.pinnedVersion !== pinnedVersion || previous.customPath !== customPath || previous.enabled !== enabled
            return { recipeId: item.recipeId, pinnedVersion, customPath, enabled, updatedAt: changed ? now : previous.updatedAt }
        })

        const nextCustomRecipes: CustomRecipeRow[] = input.customRecipes.map((item) => {
            const recipeJson = stableStringify(item.recipe)
            const previous = existingCustomRecipes.find((row) => row.recipeId === item.recipeId)
            const changed = !previous || previous.recipeJson !== recipeJson
            return { recipeId: item.recipeId, recipeJson, updatedAt: changed ? now : previous.updatedAt }
        })

        await deps.db.replaceProfile(userId, nextEnvironments, nextCustomRecipes)
        return get(userId)
    }

    return { get, replace }
}

export type ProfileService = ReturnType<typeof createProfileService>
