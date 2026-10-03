import { useCallback, useEffect, useMemo, useState } from 'react'
import { apiFetch } from '../../lib/api'

export function useFournisseursPage(search) {
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const [open, setOpen] = useState(false)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [editing, setEditing] = useState(null)
  const [deleting, setDeleting] = useState(null)
  const [submitting, setSubmitting] = useState(false)

  const loadAll = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await apiFetch('/api/fournisseurs?per_page=1000')
      const list = Array.isArray(res?.data) ? res.data : res?.data?.data || []
      setItems(list)
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
    if (!q) return items
    return items.filter((f) => {
      const nom = (f?.nom || '').toString().toLowerCase()
      const tel = (f?.telephone || '').toString().toLowerCase()
      const email = (f?.email || '').toString().toLowerCase()
      return nom.includes(q) || tel.includes(q) || email.includes(q)
    })
  }, [items, search])

  function openAdd() {
    setEditing(null)
    setOpen(true)
  }

  function openEdit(item) {
    setEditing(item)
    setOpen(true)
  }

  function openDelete(item) {
    setDeleting(item)
    setConfirmOpen(true)
  }

  async function submit(payload) {
    setError('')
    setSubmitting(true)
    try {
      if (editing?.id) {
        await apiFetch(`/api/fournisseurs/${editing.id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        })
      } else {
        await apiFetch('/api/fournisseurs', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        })
      }
      setOpen(false)
      await loadAll()
    } catch (e2) {
      setError(e2?.message || 'Erreur')
    } finally {
      setSubmitting(false)
    }
  }

  async function confirmDelete() {
    if (!deleting?.id) return
    setError('')
    setSubmitting(true)
    try {
      await apiFetch(`/api/fournisseurs/${deleting.id}`, { method: 'DELETE' })
      setConfirmOpen(false)
      setDeleting(null)
      await loadAll()
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setSubmitting(false)
    }
  }

  return {
    loading,
    error,
    open,
    setOpen,
    confirmOpen,
    setConfirmOpen,
    editing,
    deleting,
    setDeleting,
    submitting,
    filtered,
    openAdd,
    openEdit,
    openDelete,
    submit,
    confirmDelete
  }
}
