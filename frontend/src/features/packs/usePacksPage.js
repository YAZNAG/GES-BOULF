import { useCallback, useEffect, useMemo, useState } from 'react'
import { toast } from '../../lib/toast'
import { createPack, deletePack, fetchArticles, fetchPacks, updatePack } from './api'

export function usePacksPage({ search, enabled }) {
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [packs, setPacks] = useState([])
  const [articles, setArticles] = useState([])
  const [open, setOpen] = useState(false)
  const [modalMode, setModalMode] = useState('create')
  const [editing, setEditing] = useState(null)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [deleting, setDeleting] = useState(null)
  const [submitting, setSubmitting] = useState(false)

  const loadAll = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const [p, a] = await Promise.all([fetchPacks(), fetchArticles()])
      setPacks(p)
      setArticles(a)
    } catch (e) {
      setError(e?.message || 'Erreur de chargement')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    if (!enabled) return
    loadAll()
  }, [enabled, loadAll])

  const filtered = useMemo(() => {
    const q = (search || '').trim().toLowerCase()
    return packs.filter((p) => {
      if (!q) return true
      return (p?.nom || '').toString().toLowerCase().includes(q)
    })
  }, [packs, search])

  const openCreate = useCallback(() => {
    setModalMode('create')
    setEditing(null)
    setOpen(true)
  }, [])

  const openEdit = useCallback((p) => {
    setModalMode('edit')
    setEditing(p)
    setOpen(true)
  }, [])

  const askDelete = useCallback((p) => {
    setDeleting(p)
    setConfirmOpen(true)
  }, [])

  const submit = useCallback(
    async (values) => {
      setSubmitting(true)
      setError('')
      try {
        if (modalMode === 'edit' && editing?.id) {
          await updatePack(editing.id, values)
          toast({ type: 'success', message: 'Pack modifié.' })
        } else {
          await createPack(values)
          toast({ type: 'success', message: 'Pack créé.' })
        }
        setOpen(false)
        setEditing(null)
        await loadAll()
      } catch (e) {
        setError(e?.message || "Erreur lors de l'enregistrement")
        toast({ type: 'error', message: e?.message || 'Erreur' })
      } finally {
        setSubmitting(false)
      }
    },
    [editing?.id, loadAll, modalMode]
  )

  const confirmDelete = useCallback(async () => {
    if (!deleting?.id) return
    setSubmitting(true)
    setError('')
    try {
      await deletePack(deleting.id)
      toast({ type: 'success', message: 'Pack supprimé.' })
      setConfirmOpen(false)
      setDeleting(null)
      await loadAll()
    } catch (e) {
      setError(e?.message || 'Erreur')
      toast({ type: 'error', message: e?.message || 'Erreur' })
    } finally {
      setSubmitting(false)
    }
  }, [deleting?.id, loadAll])

  const togglePackStatus = useCallback(
    async (p) => {
      try {
        await updatePack(p.id, { ...p, actif: !p.actif })
        toast({ type: 'success', message: 'Statut mis à jour.' })
        await loadAll()
      } catch {
        toast({ type: 'error', message: 'Erreur lors de la mise à jour.' })
      }
    },
    [loadAll]
  )

  return {
    loading,
    error,
    packs,
    articles,
    open,
    modalMode,
    editing,
    confirmOpen,
    deleting,
    submitting,
    filtered,

    setOpen,
    setConfirmOpen,
    setDeleting,

    openCreate,
    openEdit,
    askDelete,
    submit,
    confirmDelete,
    togglePackStatus,
  }
}

