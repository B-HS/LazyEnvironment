import { eq } from 'drizzle-orm'
import { customRecipes, environments } from '../db/schema'
import { createProfileService } from '../service/domain/profile/profile.service'
import type { BatchItem } from 'drizzle-orm/batch'
import type { Database } from '../db'

export const composeProfile = (db: Database) => {
    const profileService = createProfileService({
        db: {
            listEnvironments: async (userId) => {
                const rows = await db.select().from(environments).where(eq(environments.userId, userId))
                return rows.map((row) => ({
                    recipeId: row.recipeId,
                    pinnedVersion: row.pinnedVersion,
                    customPath: row.customPath,
                    enabled: row.enabled,
                    updatedAt: row.updatedAt,
                }))
            },
            listCustomRecipes: async (userId) => {
                const rows = await db.select().from(customRecipes).where(eq(customRecipes.userId, userId))
                return rows.map((row) => ({ recipeId: row.recipeId, recipeJson: row.recipeJson, updatedAt: row.updatedAt }))
            },
            replaceProfile: async (userId, environmentRows, customRecipeRows) => {
                const statements: [BatchItem<'sqlite'>, ...BatchItem<'sqlite'>[]] = [
                    db.delete(environments).where(eq(environments.userId, userId)),
                    db.delete(customRecipes).where(eq(customRecipes.userId, userId)),
                ]
                if (environmentRows.length > 0) {
                    statements.push(db.insert(environments).values(environmentRows.map((row) => ({ userId, ...row }))))
                }
                if (customRecipeRows.length > 0) {
                    statements.push(db.insert(customRecipes).values(customRecipeRows.map((row) => ({ userId, ...row }))))
                }
                await db.batch(statements)
            },
        },
    })
    return { profileService }
}
