export const fmtInt = (n) => new Intl.NumberFormat('fr-FR').format(Number(n || 0))

/** Extrait la liste d'une réponse paginée Laravel (ou d'un tableau). */
export const listOf = (res) => (Array.isArray(res) ? res : Array.isArray(res?.data) ? res.data : res?.data?.data || [])
