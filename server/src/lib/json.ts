export const stableStringify = (value: unknown): string => {
    if (value === null || typeof value !== 'object') return JSON.stringify(value) ?? 'null'
    if (Array.isArray(value)) return `[${value.map(stableStringify).join(',')}]`
    const source = value as Record<string, unknown>
    const entries = Object.keys(source)
        .sort()
        .map((key) => `${JSON.stringify(key)}:${stableStringify(source[key])}`)
    return `{${entries.join(',')}}`
}
