import { z } from 'zod'

export const devAuthSchema = z.object({
    login: z
        .string()
        .min(1)
        .max(100)
        .regex(/^[a-zA-Z0-9._-]+$/),
})

export type DevAuthInput = z.infer<typeof devAuthSchema>
