import { apiFetch } from '../../lib/api'

export async function fetchCommandesVente() {
  const data = await apiFetch('/api/commandes_vente')
  return data?.data || data || []
}

export async function fetchClients() {
  const data = await apiFetch('/api/clients')
  return data?.data || data || []
}

export async function updateCommandeVente(id, payload) {
  return apiFetch(`/api/commandes_vente/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
}

export async function deleteCommandeVente(id) {
  return apiFetch(`/api/commandes_vente/${id}`, { method: 'DELETE' })
}

