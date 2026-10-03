import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { apiFetch } from '../../lib/api'

export function useSubCategoriesPage(categoryId) {
  const [open, setOpen] = useState(false)
  const [category, setCategory] = useState(null)
  const [subCategories, setSubCategories] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const errTimerRef = useRef(null)

  function showTempError(message) {
    const msg = (message || '').toString()
    if (!msg) return
    setError(msg)
    if (errTimerRef.current) window.clearTimeout(errTimerRef.current)
    errTimerRef.current = window.setTimeout(() => setError(''), 3800)
  }

  const load = useCallback(async () => {
    setError('')
    setLoading(true)
    try {
      const [cat, res] = await Promise.all([
        apiFetch(`/api/categories/${categoryId}`),
        apiFetch('/api/sous_categories?per_page=1000'),
      ])

      setCategory(cat)

      const items = Array.isArray(res?.data) ? res.data : res?.data?.data || []
      const filtered = items
        .filter((s) => String(s.categorie_id) === String(categoryId))
        .map((s) => ({
          id: s.id,
          nom: s.nom,
          name_ar: s.name_ar,
          name_fr: s.name_fr,
          image: s.image || null,
          produits: Math.floor(Math.random() * 30),
        }))

      setSubCategories(filtered)
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setLoading(false)
    }
  }, [categoryId])

  useEffect(() => {
    load()
  }, [load])

  useEffect(() => {
    return () => {
      if (errTimerRef.current) window.clearTimeout(errTimerRef.current)
    }
  }, [])

  const totals = useMemo(() => {
    const totalSous = subCategories.length
    const totalProduits = subCategories.reduce((sum, s) => sum + s.produits, 0)
    return { totalSous, totalProduits }
  }, [subCategories])

  async function addSub(values) {
    const form = new FormData()
    form.append('categorie_id', String(Number(categoryId)))
    form.append('nom', values.nom)
    form.append('name_ar', values.name_ar)
    form.append('name_fr', values.name_fr)
    form.append('description', '')
    form.append('image', values.file)
    await apiFetch('/api/sous_categories', { method: 'POST', body: form })
    setOpen(false)
    await load()
  }

  async function deleteSub(s) {
    try {
      await apiFetch(`/api/sous_categories/${s.id}`, { method: 'DELETE' })
      await load()
    } catch (e) {
      showTempError(e?.message || 'Erreur')
    }
  }

  return {
    open,
    setOpen,
    category,
    subCategories,
    totals,
    loading,
    error,
    addSub,
    deleteSub,
  }
}
