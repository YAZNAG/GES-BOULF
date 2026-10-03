import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { apiFetch } from '../../lib/api'
import { toast } from '../../lib/toast'
import {
  createArticleWithImage,
  createPrixArticle,
  createStock,
  deleteArticle,
  fetchCategories,
  fetchMarques,
  fetchSousCategories,
  fetchUnites,
  updateArticle,
  updateArticleWithImage,
  updatePrixArticle,
  updateStock,
} from './api'

export const PER_PAGE = 48

/** Article API → objet utilisé par les cartes, la liste et ProductModal. */
export function mapArticle(a) {
  const sc = a.sous_categorie || a.sousCategorie || null
  const cat = sc?.categorie || null
  return {
    id: a.id,
    code_article: a.code_article,
    nom: a.nom,
    name_ar: a.name_ar,
    name_fr: a.name_fr,
    actif: !!a.actif,
    unite: a.unite || 'pièce',
    prix: Number(a?.prix?.prix_vente ?? 0),
    prix_achat: Number(a?.prix?.prix_achat ?? 0),
    prix_id: a?.prix?.id ?? null,
    stock: Number(a?.stock?.quantite ?? 0),
    stock_id: a?.stock?.id ?? null,
    seuil_min: Number(a?.stock?.seuil_min ?? 0),
    img: a.image || null,
    marque_id: a.marque_id,
    marqueName: a.marque?.nom || '',
    sous_categorie_id: a.sous_categorie_id,
    subCategoryName: sc?.name_fr || sc?.nom || '',
    categoryName: cat?.name_fr || cat?.nom || '',
    familleName: cat?.famille?.nom_fr || '',
  }
}

/** Filtres de l'URL : ?q=&famille=&categorie=&sous_categorie=&statut=&sort=&page=&vue= */
const FILTER_KEYS = ['q', 'famille', 'categorie', 'sous_categorie', 'statut', 'sort']

export function useCatalogueProduits() {
  const [params, setParams] = useSearchParams()
  const legacySub = params.get('subCategoryId')

  const filters = {
    q: params.get('q') || '',
    famille: params.get('famille') || '',
    categorie: params.get('categorie') || '',
    sous_categorie: params.get('sous_categorie') || legacySub || '',
    statut: params.get('statut') || '',
    sort: params.get('sort') || 'nom',
  }
  const page = Math.max(1, Number(params.get('page') || 1))
  const view = params.get('vue') === 'liste' ? 'list' : 'grid'

  const setFilter = useCallback(
    (patch) => {
      setParams(
        (prev) => {
          const next = new URLSearchParams(prev)
          next.delete('subCategoryId')
          for (const [k, v] of Object.entries(patch)) {
            if (v === '' || v == null) next.delete(k)
            else next.set(k, String(v))
          }
          // Tout changement de filtre ramène à la page 1.
          if (!('page' in patch)) next.delete('page')
          return next
        },
        { replace: true }
      )
    },
    [setParams]
  )

  const setView = useCallback((v) => setFilter({ vue: v === 'list' ? 'liste' : '', page: page > 1 ? page : '' }), [setFilter, page])
  const setPage = useCallback((p) => {
    setFilter({ page: p > 1 ? p : '' })
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }, [setFilter])

  // Référentiels (chargés une fois).
  const [familles, setFamilles] = useState([])
  const [categories, setCategories] = useState([])
  const [sousCategories, setSousCategories] = useState([])
  const [unites, setUnites] = useState([])
  const [marques, setMarques] = useState([])

  const loadRefs = useCallback(async () => {
    const [fam, cat, sc, un, mq] = await Promise.all([
      apiFetch('/api/familles?per_page=200'),
      fetchCategories(),
      fetchSousCategories(),
      fetchUnites(),
      fetchMarques(),
    ])
    setFamilles(Array.isArray(fam?.data) ? fam.data : [])
    setCategories(cat)
    setSousCategories(sc)
    setUnites(Array.isArray(un) ? un : [])
    setMarques(mq)
  }, [])


  // Page de produits (côté serveur).
  const [items, setItems] = useState([])
  const [meta, setMeta] = useState({ total: 0, last_page: 1, from: 0, to: 0 })
  const [stats, setStats] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const reqId = useRef(0)

  const queryString = useMemo(() => {
    const qs = new URLSearchParams({ per_page: String(PER_PAGE), page: String(page), with_stats: '1' })
    if (filters.q) qs.set('q', filters.q)
    if (filters.famille) qs.set('famille_id', filters.famille)
    if (filters.categorie) qs.set('categorie_id', filters.categorie)
    if (filters.sous_categorie) qs.set('sous_categorie_id', filters.sous_categorie)
    if (filters.statut) qs.set('statut', filters.statut)
    if (filters.sort && filters.sort !== 'nom') qs.set('sort', filters.sort)
    return qs.toString()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, ...FILTER_KEYS.map((k) => filters[k])])

  const loadPage = useCallback(async () => {
    const id = ++reqId.current
    setLoading(true)
    setError('')
    try {
      const res = await apiFetch(`/api/articles?${queryString}`)
      if (id !== reqId.current) return
      setItems((res?.data || []).map(mapArticle))
      setMeta({ total: res?.total ?? 0, last_page: res?.last_page ?? 1, from: res?.from ?? 0, to: res?.to ?? 0 })
      setStats(res?.stats || null)
    } catch (e) {
      if (id === reqId.current) setError(e?.message || 'Chargement impossible')
    } finally {
      if (id === reqId.current) setLoading(false)
    }
  }, [queryString])

  useEffect(() => {
    loadPage()
  }, [loadPage])

  // Référentiels après la première page de produits (le serveur de dev traite une requête à la fois).
  useEffect(() => {
    loadRefs().catch(() => {})
  }, [loadRefs])

  // Fenêtres
  const [modal, setModal] = useState(null) // { mode: 'create'|'edit', product }
  const [toDelete, setToDelete] = useState(null)
  const [submitting, setSubmitting] = useState(false)

  const run = useCallback(
    async (fn, okMessage) => {
      setSubmitting(true)
      try {
        await fn()
        toast({ type: 'success', message: okMessage })
        await loadPage()
        return true
      } catch (e) {
        toast({ type: 'error', message: e?.message || 'Erreur' })
        return false
      } finally {
        setSubmitting(false)
      }
    },
    [loadPage]
  )

  const addProduct = useCallback(
    async (values) => {
      const ok = await run(async () => {
        if (!values?.file) throw new Error('Image obligatoire.')
        const prix = Number(values.prix)
        if (!Number.isFinite(prix)) throw new Error('Prix invalide.')
        await createArticleWithImage({
          sous_categorie_id: values.sous_categorie_id,
          marque_id: values.marque_id,
          code_article: (values.code_article || '').toString().trim() || `ART-${Date.now()}`,
          name_ar: values.name_ar,
          name_fr: values.name_fr,
          unite: values.unite || 'pièce',
          file: values.file,
          prix_achat: 0,
          prix_vente: prix,
          prix_gros: prix,
          stock_initial: 0,
          seuil_min: Number(values.seuil_min ?? 0),
        })
      }, 'Produit ajouté.')
      if (ok) setModal(null)
    },
    [run]
  )

  const updateProduct = useCallback(
    async (values) => {
      const p = modal?.product
      if (!p?.id) return
      const ok = await run(async () => {
        const base = {
          sous_categorie_id: values.sous_categorie_id,
          marque_id: values.marque_id,
          code_article: (values.code_article || '').toString().trim() || p.code_article,
          name_ar: values.name_ar,
          name_fr: values.name_fr,
          unite: values.unite || p.unite || 'pièce',
        }
        if (values.file) await updateArticleWithImage(p.id, { ...base, file: values.file })
        else await updateArticle(p.id, base)

        const prix = Number(values.prix)
        const prixPayload = { prix_achat: p.prix_achat, prix_vente: prix, prix_gros: prix, prix_promo: null }
        if (p.prix_id) await updatePrixArticle(p.prix_id, prixPayload)
        else await createPrixArticle({ article_id: p.id, ...prixPayload })

        const seuil = Number(values.seuil_min ?? 0)
        if (p.stock_id) await updateStock(p.stock_id, { quantite: p.stock, seuil_min: seuil })
        else await createStock({ article_id: p.id, quantite: 0, seuil_min: seuil })
      }, 'Produit modifié.')
      if (ok) setModal(null)
    },
    [modal, run]
  )

  const toggleActif = useCallback(
    (p) => run(() => updateArticle(p.id, { actif: !p.actif }), p.actif ? 'Produit désactivé.' : 'Produit activé.'),
    [run]
  )

  const confirmDelete = useCallback(async () => {
    const p = toDelete
    if (!p) return
    const ok = await run(() => deleteArticle(p.id), 'Produit supprimé.')
    if (ok) setToDelete(null)
  }, [toDelete, run])

  const exportProducts = useCallback(async () => {
    try {
      const qs = new URLSearchParams(queryString)
      qs.set('per_page', '5000')
      qs.set('page', '1')
      qs.delete('with_stats')
      const res = await apiFetch(`/api/articles?${qs}`)
      const rows = (res?.data || []).map(mapArticle)
      if (!rows.length) {
        toast({ type: 'error', message: 'Aucun produit à exporter.' })
        return
      }
      const headers = ['ID', 'Code EAN', 'Nom', 'Nom arabe', 'Marque', 'Famille', 'Catégorie', 'Sous-catégorie', 'Unité', 'Prix vente', 'Stock', 'Seuil min', 'Actif']
      const lines = rows.map((p) =>
        [p.id, p.code_article, p.name_fr || p.nom, p.name_ar, p.marqueName, p.familleName, p.categoryName, p.subCategoryName, p.unite, p.prix.toFixed(2), p.stock, p.seuil_min, p.actif ? 'oui' : 'non']
          .map((f) => `"${String(f ?? '').replace(/"/g, '""')}"`)
          .join(';')
      )
      const blob = new Blob(['﻿' + [headers.join(';'), ...lines].join('\n')], { type: 'text/csv;charset=utf-8;' })
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `catalogue_produits_${new Date().toISOString().slice(0, 10)}.csv`
      document.body.appendChild(a)
      a.click()
      a.remove()
      URL.revokeObjectURL(url)
    } catch (e) {
      toast({ type: 'error', message: e?.message || 'Export impossible' })
    }
  }, [queryString])

  return {
    filters,
    page,
    view,
    setFilter,
    setView,
    setPage,
    familles,
    categories,
    sousCategories,
    unites,
    marques,
    items,
    meta,
    stats,
    loading,
    error,
    modal,
    setModal,
    toDelete,
    setToDelete,
    submitting,
    addProduct,
    updateProduct,
    toggleActif,
    confirmDelete,
    exportProducts,
  }
}
