import { apiFetch } from '../../lib/api'

export async function fetchArticles(perPage = 1000) {
  const data = await apiFetch(`/api/articles?per_page=${perPage}`)
  return Array.isArray(data?.data) ? data.data : data?.data?.data || []
}

export async function fetchSousCategories(perPage = 1000) {
  const data = await apiFetch(`/api/sous_categories?per_page=${perPage}`)
  return Array.isArray(data?.data) ? data.data : data?.data?.data || []
}

export async function fetchCategories(perPage = 1000) {
  const data = await apiFetch(`/api/categories?per_page=${perPage}`)
  return Array.isArray(data?.data) ? data.data : data?.data?.data || []
}

export async function fetchUnites(perPage = 1000) {
  const data = await apiFetch(`/api/unites?per_page=${perPage}`)
  return Array.isArray(data?.data) ? data.data : data?.data?.data || []
}

export async function fetchMarques(perPage = 1000) {
  const data = await apiFetch(`/api/marques?per_page=${perPage}`)
  return Array.isArray(data?.data) ? data.data : data?.data?.data || []
}

export async function createArticleWithImage({ 
  sous_categorie_id, marque_id, code_article, name_ar, name_fr, unite, file,
  prix_achat, prix_vente, prix_gros, stock_initial, seuil_min 
}) {
  const form = new FormData()
  form.append('sous_categorie_id', String(sous_categorie_id))
  if (marque_id) form.append('marque_id', String(marque_id))
  form.append('code_article', String(code_article))
  if (name_ar) form.append('name_ar', String(name_ar))
  if (name_fr) form.append('name_fr', String(name_fr))
  form.append('unite', String(unite || 'pièce'))
  form.append('actif', '1')
  form.append('image', file)
  
  if (prix_achat !== undefined && prix_achat !== null) form.append('prix_achat', String(prix_achat))
  if (prix_vente !== undefined && prix_vente !== null) form.append('prix_vente', String(prix_vente))
  if (prix_gros !== undefined && prix_gros !== null) form.append('prix_gros', String(prix_gros))
  if (stock_initial !== undefined && stock_initial !== null) form.append('stock_initial', String(stock_initial))
  if (seuil_min !== undefined && seuil_min !== null) form.append('seuil_min', String(seuil_min))

  return apiFetch('/api/articles', {
    method: 'POST',
    body: form,
  })
}

export async function updateArticle(id, payload) {
  return apiFetch(`/api/articles/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
}

export async function updateArticleWithImage(id, { sous_categorie_id, marque_id, code_article, name_ar, name_fr, unite, file }) {
  const form = new FormData()
  form.append('_method', 'PUT')
  form.append('sous_categorie_id', String(sous_categorie_id))
  if (marque_id) form.append('marque_id', String(marque_id))
  form.append('code_article', String(code_article))
  if (name_ar) form.append('name_ar', String(name_ar))
  if (name_fr) form.append('name_fr', String(name_fr))
  form.append('unite', String(unite || 'pièce'))
  form.append('image', file)

  return apiFetch(`/api/articles/${id}`, {
    method: 'POST',
    body: form,
  })
}

export async function deleteArticle(id) {
  return apiFetch(`/api/articles/${id}`, { method: 'DELETE' })
}

export async function createPrixArticle(payload) {
  return apiFetch('/api/prix_articles', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
}

export async function updatePrixArticle(id, payload) {
  return apiFetch(`/api/prix_articles/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
}

export async function createStock(payload) {
  return apiFetch('/api/stock', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
}

export async function updateStock(id, payload) {
  return apiFetch(`/api/stock/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
}

