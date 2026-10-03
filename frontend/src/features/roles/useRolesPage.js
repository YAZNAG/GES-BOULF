import { useCallback, useEffect, useMemo, useState } from 'react'
import { apiFetch } from '../../lib/api'
import { toast } from '../../lib/toast'
import { useAuth } from '../../auth/authContext'

export function useRolesPage() {
  const { hasPermission } = useAuth()
  const [roles, setRoles] = useState([])
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [open, setOpen] = useState(false)
  const [modalMode, setModalMode] = useState('create')
  const [editing, setEditing] = useState(null)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [deleting, setDeleting] = useState(null)
  const [submitting, setSubmitting] = useState(false)
  const [modalSeed, setModalSeed] = useState(0)

  const loadAll = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const [rolesRes, usersRes] = await Promise.all([
        apiFetch('/api/roles?per_page=1000'),
        apiFetch('/api/utilisateurs?per_page=1000'),
      ])
      const r = Array.isArray(rolesRes?.data) ? rolesRes.data : rolesRes?.data?.data || []
      const u = Array.isArray(usersRes?.data) ? usersRes.data : usersRes?.data?.data || []
      setRoles(r)
      setUsers(u)
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    if (!hasPermission('systeme.settings')) return
    loadAll()
  }, [hasPermission, loadAll])

  const usersByRoleId = useMemo(() => {
    const map = new Map()
    for (const u of users) {
      const id = String(u?.role_id ?? u?.role?.id ?? '')
      if (!id) continue
      map.set(id, (map.get(id) || 0) + 1)
    }
    return map
  }, [users])

  const roleCards = useMemo(() => {
    return roles.map((r) => {
      const perms = new Set((Array.isArray(r?.permissions) ? r.permissions : []).map(String))
      const count = usersByRoleId.get(String(r.id)) || 0
      const isAdmin = (r?.nom || '').toString().toLowerCase() === 'admin' || (r?.nom || '').toString().toLowerCase().includes('admin')
      return {
        id: r.id,
        nom: r.nom,
        description: r.description,
        permissions: perms,
        rawPermissions: Array.isArray(r?.permissions) ? r.permissions : [],
        usersCount: count,
        badgeTone: isAdmin ? 'red' : 'blue',
      }
    })
  }, [roles, usersByRoleId])

  function openCreate() {
    setModalMode('create')
    setEditing(null)
    setModalSeed((s) => s + 1)
    setOpen(true)
  }

  function openEdit(r) {
    setModalMode('edit')
    setEditing(r)
    setModalSeed((s) => s + 1)
    setOpen(true)
  }

  function askDelete(r) {
    setDeleting(r)
    setConfirmOpen(true)
  }

  async function submit(values) {
    setSubmitting(true)
    setError('')
    try {
      if (modalMode === 'edit' && editing?.id) {
        await apiFetch(`/api/roles/${editing.id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(values),
        })
        toast({ type: 'success', message: 'Rôle mis à jour.' })
      } else {
        await apiFetch('/api/roles', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(values),
        })
        toast({ type: 'success', message: 'Rôle créé.' })
      }
      setOpen(false)
      setEditing(null)
      await loadAll()
    } catch (e) {
      setError(e?.message || 'Erreur')
      toast({ type: 'error', message: e?.message || 'Erreur' })
    } finally {
      setSubmitting(false)
    }
  }

  async function confirmDelete() {
    if (!deleting?.id) return
    setSubmitting(true)
    setError('')
    try {
      await apiFetch(`/api/roles/${deleting.id}`, { method: 'DELETE' })
      toast({ type: 'success', message: 'Rôle supprimé.' })
      setConfirmOpen(false)
      setDeleting(null)
      await loadAll()
    } catch (e) {
      toast({ type: 'error', message: e?.message || 'Impossible de supprimer le rôle.' })
      setError(e?.message || 'Erreur')
    } finally {
      setSubmitting(false)
    }
  }

  return {
    hasPermission,
    loading,
    error,
    open,
    setOpen,
    modalMode,
    editing,
    setEditing,
    confirmOpen,
    setConfirmOpen,
    deleting,
    setDeleting,
    submitting,
    modalSeed,
    roleCards,
    openCreate,
    openEdit,
    askDelete,
    submit,
    confirmDelete
  }
}
