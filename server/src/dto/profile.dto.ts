import { z } from 'zod'

const environmentInputSchema = z.object({
    recipeId: z.string().min(1),
    pinnedVersion: z.string().nullish(),
    customPath: z.string().nullish(),
    enabled: z.boolean().optional(),
})

const customRecipeInputSchema = z.object({
    recipeId: z.string().min(1),
    recipe: z.record(z.string(), z.json()),
})

const hasUniqueRecipeIds = (items: { recipeId: string }[]) => new Set(items.map((item) => item.recipeId)).size === items.length

export const profileUpdateSchema = z
    .object({
        environments: z.array(environmentInputSchema),
        customRecipes: z.array(customRecipeInputSchema),
    })
    .refine((value) => hasUniqueRecipeIds(value.environments), { message: 'environments must have unique recipeId values', path: ['environments'] })
    .refine((value) => hasUniqueRecipeIds(value.customRecipes), {
        message: 'customRecipes must have unique recipeId values',
        path: ['customRecipes'],
    })

export type ProfileUpdateInput = z.infer<typeof profileUpdateSchema>
export type EnvironmentInput = z.infer<typeof environmentInputSchema>
export type CustomRecipeInput = z.infer<typeof customRecipeInputSchema>
