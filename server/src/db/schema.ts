import { integer, primaryKey, sqliteTable, text } from 'drizzle-orm/sqlite-core'

export const users = sqliteTable('lazyenv_users', {
    id: text('id').primaryKey(),
    login: text('login').notNull(),
    createdAt: integer('created_at').notNull(),
})

export const environments = sqliteTable(
    'lazyenv_environments',
    {
        userId: text('user_id').notNull(),
        recipeId: text('recipe_id').notNull(),
        pinnedVersion: text('pinned_version'),
        customPath: text('custom_path'),
        enabled: integer('enabled', { mode: 'boolean' }).notNull().default(true),
        updatedAt: integer('updated_at').notNull(),
    },
    (table) => [primaryKey({ columns: [table.userId, table.recipeId] })],
)

export const customRecipes = sqliteTable(
    'lazyenv_custom_recipes',
    {
        userId: text('user_id').notNull(),
        recipeId: text('recipe_id').notNull(),
        recipeJson: text('recipe_json').notNull(),
        updatedAt: integer('updated_at').notNull(),
    },
    (table) => [primaryKey({ columns: [table.userId, table.recipeId] })],
)

export type UserRow = typeof users.$inferSelect
export type EnvironmentRecord = typeof environments.$inferSelect
export type CustomRecipeRecord = typeof customRecipes.$inferSelect
