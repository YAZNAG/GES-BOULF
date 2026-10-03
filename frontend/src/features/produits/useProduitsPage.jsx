import { useCallback, useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { toast } from '../../lib/toast'
import {
  createArticleWithImage,
  createPrixArticle,
  createStock,
  deleteArticle,
  fetchArticles,
  fetchCategories,
  fetchMarques,
  fetchSousCategories,
  fetchUnites,
  updateArticle,
  updateArticleWithImage,
  updatePrixArticle,
  updateStock,
} from './api'

function mapArticles({ articles, categories, sousCategories }) {
  const catById = new Map(categories.map((c) => [String(c.id), c]))
  const scById = new Map(sousCategories.map((s) => [String(s.id), s]))

  return articles.map((a) => ({
    id: a.id,
    code_article: a.code_article,
    nom: a.nom,
    name_ar: a.name_ar,
    name_fr: a.name_fr,
    subCategoryName: a?.sous_categorie?.nom || a?.sousCategorie?.nom || '',
    categoryName: (() => {
      const sid = String(a.sous_categorie_id ?? '')
      const s = scById.get(sid)
      const cid = String(s?.categorie_id ?? '')
      return catById.get(cid)?.nom || s?.categorie?.nom || ''
    })(),
    unite: a.unite || 'pièce',
    poids: 0,
    prix: Number(a?.prix?.prix_vente ?? 0),
    prix_achat: Number(a?.prix?.prix_achat ?? 0),
    prix_id: a?.prix?.id ?? null,
    stock: Number(a?.stock?.quantite ?? 0),
    stock_id: a?.stock?.id ?? null,
    seuil_min: Number(a?.stock?.seuil_min ?? 0),
    img: a.image || '/imagelogin.png',
    marque_id: a.marque_id,
    marqueName: a.marque?.nom || '',
    sous_categorie_id: a.sous_categorie_id,
    categorie_id: (() => {
      const sid = String(a.sous_categorie_id ?? '')
      const s = scById.get(sid)
      return s?.categorie_id ?? null
    })(),
  }))
}

export function useProduitsPage({ search, setSearch, navigate }) {
  const [searchParams] = useSearchParams()
  const initialSubCat = searchParams.get('subCategoryId')

  const [open, setOpen] = useState(false)
  const [modalMode, setModalMode] = useState('create')
  const [editing, setEditing] = useState(null)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [deleting, setDeleting] = useState(null)
  const [view, setView] = useState('list')
  const [categoryId, setCategoryId] = useState('all')
  const [subCategoryId, setSubCategoryId] = useState(initialSubCat || 'all')

  const [products, setProducts] = useState([])
  const [sousCategories, setSousCategories] = useState([])
  const [categories, setCategories] = useState([])
  const [unites, setUnites] = useState([])
  const [marques, setMarques] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [submitting, setSubmitting] = useState(false)

  const loadAll = useCallback(async () => {
    setError('')
    setSuccess('')
    setLoading(true)
    try {
      const [articles, sc, cat, unitesRes, marquesRes] = await Promise.all([
        fetchArticles(),
        fetchSousCategories(),
        fetchCategories(),
        fetchUnites(),
        fetchMarques(),
      ])
      setSousCategories(sc)
      setCategories(cat)
      setUnites(Array.isArray(unitesRes) ? unitesRes : [])
      setMarques(marquesRes)
      setProducts(mapArticles({ articles, categories: cat, sousCategories: sc }))

      if (initialSubCat && initialSubCat !== 'all') {
        const found = sc.find((s) => String(s.id) === String(initialSubCat))
        if (found) setCategoryId(String(found.categorie_id))
      }
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    loadAll()
  }, [loadAll])

  const filtered = useMemo(() => {
    const q = (search || '').trim().toLowerCase()
    return products.filter((p) => {
      const okCategory = categoryId === 'all' ? true : String(p.categorie_id ?? '') === String(categoryId)
      const okSubCategory = subCategoryId === 'all' ? true : String(p.sous_categorie_id ?? '') === String(subCategoryId)
      const okQuery = !q ? true : (p.nom || '').toString().toLowerCase().includes(q)
      return okCategory && okSubCategory && okQuery
    })
  }, [products, search, categoryId, subCategoryId])

  const openCreate = useCallback(() => {
    setError('')
    setSuccess('')
    setEditing(null)
    setModalMode('create')
    setOpen(true)
  }, [])

  const openEdit = useCallback((product) => {
    setError('')
    setSuccess('')
    setEditing(product)
    setModalMode('edit')
    setOpen(true)
  }, [])

  const openDetails = useCallback(
    (product) => {
      if (!product?.id) return
      navigate(`/admin/produits/${product.id}`)
    },
    [navigate]
  )

  const askDelete = useCallback((product) => {
    setError('')
    setSuccess('')
    setDeleting(product)
    setConfirmOpen(true)
  }, [])

  const addProduct = useCallback(
    async (values) => {
      setSubmitting(true)
      setError('')
      setSuccess('')
      try {
        if (!values?.file) throw new Error('Image obligatoire.')
        const prixNum = Number(values.prix)
        if (!Number.isFinite(prixNum)) throw new Error('Prix invalide.')
        const seuilMinNum = Number(values.seuil_min ?? 0)
        if (!Number.isFinite(seuilMinNum) || seuilMinNum < 0) throw new Error('Stock minimal invalide.')

        const code_article = (values?.code_article || '').toString().trim() || `ART-${Date.now()}`

        // Single atomic call to create Article + Price + Stock
        await createArticleWithImage({
          sous_categorie_id: values.sous_categorie_id,
          marque_id: values.marque_id,
          code_article,
          nom: values.nom,
          name_ar: values.name_ar,
          name_fr: values.name_fr,
          unite: values.unite || 'pièce',
          file: values.file,
          prix_achat: 0,
          prix_vente: prixNum,
          prix_gros: prixNum,
          stock_initial: 0,
          seuil_min: seuilMinNum,
        })

        setOpen(false)
        setSuccess('Produit ajouté.')
        toast({ type: 'success', message: 'Produit ajouté.' })
        await loadAll()
      } catch (e) {
        const msg = e?.message || 'Erreur'
        setError(msg)
        toast({ type: 'error', message: msg })
      } finally {
        setSubmitting(false)
      }
    },
    [loadAll]
  )

  const updateProduct = useCallback(
    async (values) => {
      if (!editing?.id) return
      setSubmitting(true)
      setError('')
      setSuccess('')
      try {
        const nextCode = (values?.code_article || '').toString().trim() || editing.code_article

        if (values?.file) {
          await updateArticleWithImage(editing.id, {
            sous_categorie_id: values.sous_categorie_id,
            marque_id: values.marque_id,
            code_article: nextCode,
            nom: values.nom,
            name_ar: values.name_ar,
            name_fr: values.name_fr,
            unite: values.unite || editing.unite || 'pièce',
            file: values.file,
          })
        } else {
          await updateArticle(editing.id, {
            sous_categorie_id: values.sous_categorie_id,
            marque_id: values.marque_id,
            code_article: nextCode,
            nom: values.nom,
            name_ar: values.name_ar,
            name_fr: values.name_fr,
            unite: values.unite || editing.unite || 'pièce',
          })
        }

        const prixNum = Number(values.prix)
        if (editing.prix_id) {
          await updatePrixArticle(editing.prix_id, {
            prix_achat: Number(editing.prix_achat ?? 0),
            prix_vente: prixNum,
            prix_gros: prixNum,
            prix_promo: null,
          })
        } else {
          await createPrixArticle({
            article_id: editing.id,
            prix_achat: 0,
            prix_vente: prixNum,
            prix_gros: prixNum,
            prix_promo: null,
          })
        }

        const seuilMinNum = Number(values.seuil_min ?? 0)
        if (editing.stock_id) {
          await updateStock(editing.stock_id, {
            quantite: Number(editing.stock ?? 0),
            seuil_min: seuilMinNum,
          })
        } else {
          await createStock({
            article_id: editing.id,
            quantite: 0,
            seuil_min: seuilMinNum,
          })
        }

        setOpen(false)
        setSuccess('Produit modifié.')
        toast({ type: 'success', message: 'Produit modifié.' })
        await loadAll()
      } catch (e) {
        const msg = e?.message || 'Erreur'
        setError(msg)
        toast({ type: 'error', message: msg })
      } finally {
        setSubmitting(false)
      }
    },
    [editing, loadAll]
  )

  const deleteProduct = useCallback(
    async (product) => {
      if (!product?.id) return
      setSubmitting(true)
      setError('')
      setSuccess('')
      try {
        await deleteArticle(product.id)
        setConfirmOpen(false)
        setDeleting(null)
        setSuccess('Produit supprimé.')
        toast({ type: 'success', message: 'Produit supprimé.' })
        await loadAll()
      } catch (e) {
        const msg = e?.message || 'Erreur'
        setError(msg)
        toast({ type: 'error', message: msg })
      } finally {
        setSubmitting(false)
      }
    },
    [loadAll]
  )

  const exportProducts = useCallback(() => {
    if (products.length === 0) {
      toast({ type: 'warning', message: 'Aucun produit à exporter.' })
      return
    }

    const headers = ['ID', 'Référence', 'Nom', 'Nom Arabe', 'Nom Français', 'Famille', 'Catégorie', 'Unité', 'Prix Vente', 'Stock', 'Seuil Min']
    const rows = products.map((p) => [
      p.id,
      p.code_article,
      p.nom,
      p.name_ar || '',
      p.name_fr || '',
      p.categoryName,
      p.subCategoryName,
      p.unite,
      p.prix.toFixed(2),
      p.stock,
      p.seuil_min,
    ])

    const csvContent = [
      headers.join(';'),
      ...rows.map((r) => r.map((field) => `"${String(field || '').replace(/"/g, '""')}"`).join(';')),
    ].join('\n')

    const blob = new Blob(['\ufeff' + csvContent], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.setAttribute('download', `catalogue_produits_${new Date().toISOString().split('T')[0]}.csv`)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
  }, [products])

  return {
    open,
    modalMode,
    editing,
    confirmOpen,
    deleting,
    view,
    categoryId,
    subCategoryId,
    products,
    sousCategories,
    categories,
    unites,
    marques,
    loading,
    error,
    success,
    submitting,
    filtered,

    setOpen,
    setView,
    setCategoryId,
    setSubCategoryId,
    setConfirmOpen,
    setDeleting,
    setSearch,

    openCreate,
    openEdit,
    openDetails,
    askDelete,
    addProduct,
    updateProduct,
    deleteProduct,
    exportProducts,
  }
}

