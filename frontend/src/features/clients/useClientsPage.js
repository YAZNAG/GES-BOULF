import { useCallback, useEffect, useMemo, useState } from 'react'
import { apiFetch } from '../../lib/api'

export function useClientsPage(search) {
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const [open, setOpen] = useState(false)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [paymentOpen, setPaymentOpen] = useState(false)
  const [historyOpen, setHistoryOpen] = useState(false)
  const [editing, setEditing] = useState(null)
  const [deleting, setDeleting] = useState(null)
  const [payingClient, setPayingClient] = useState(null)
  const [historyClient, setHistoryClient] = useState(null)
  const [clientHistory, setClientHistory] = useState({ ventes: [], paiements: [] })
  const [submitting, setSubmitting] = useState(false)

  const [typeFilter, setTypeFilter] = useState('all')

  const loadAll = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await apiFetch('/api/clients?per_page=1000')
      const list = Array.isArray(res?.data) ? res.data : res?.data?.data || []
      setItems(list)
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setLoading(false)
    }
  }, [])

  const openHistory = async (client) => {
    setHistoryClient(client)
    setHistoryOpen(true)
    try {
      const res = await apiFetch(`/api/clients/${client.id}/history`)
      setClientHistory(res)
    } catch (e) {
      setError(e?.message || 'Erreur lors du chargement de l\'historique')
    }
  }

  useEffect(() => {
    loadAll()
  }, [loadAll])

  const filtered = useMemo(() => {
    const q = (search || '').trim().toLowerCase()
    return items.filter((c) => {
      const okType = typeFilter === 'all' ? true : (c?.type_client || '').toString() === typeFilter
      if (!okType) return false
      if (!q) return true
      const nom = (c?.nom || '').toString().toLowerCase()
      const tel = (c?.telephone || '').toString().toLowerCase()
      const email = (c?.email || '').toString().toLowerCase()
      return nom.includes(q) || tel.includes(q) || email.includes(q)
    })
  }, [items, search, typeFilter])

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

  function openPayment(item) {
    setPayingClient(item)
    setPaymentOpen(true)
  }

  async function submitPayment(payload) {
    setError('')
    setSubmitting(true)
    try {
      await apiFetch('/api/paiements', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          client_id: payingClient.id,
          ...payload
        }),
      })
      setPaymentOpen(false)
      setPayingClient(null)
      await loadAll()
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setSubmitting(false)
    }
  }

  async function submit(payload) {
    setError('')
    setSubmitting(true)
    try {
      if (editing?.id) {
        await apiFetch(`/api/clients/${editing.id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        })
      } else {
        await apiFetch('/api/clients', {
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
      await apiFetch(`/api/clients/${deleting.id}`, { method: 'DELETE' })
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
    setEditing,
    deleting,
    setDeleting,
    submitting,
    typeFilter,
    setTypeFilter,
    filtered,
    openAdd,
    openEdit,
    openDelete,
    openPayment,
    paymentOpen,
    setPaymentOpen,
    payingClient,
    openHistory,
    historyOpen,
    setHistoryOpen,
    historyClient,
    clientHistory,
    submit,
    submitPayment,
    confirmDelete
  }
}
