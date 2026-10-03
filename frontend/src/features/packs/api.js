import { apiFetch } from '../../lib/api'

export async function fetchPacks(perPage = 1000) {
  const data = await apiFetch(`/api/packs?per_page=${perPage}`)
  return Array.isArray(data?.data) ? data.data : data?.data?.data || []
}

export async function fetchArticles(perPage = 1000) {
  const data = await apiFetch(`/api/articles?per_page=${perPage}`)
  return Array.isArray(data?.data) ? data.data : data?.data?.data || []
}

export async function createPack(payload) {
  return apiFetch('/api/packs', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
}

export async function updatePack(id, payload) {
  return apiFetch(`/api/packs/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
}

export async function deletePack(id) {
  return apiFetch(`/api/packs/${id}`, { method: 'DELETE' })
}

