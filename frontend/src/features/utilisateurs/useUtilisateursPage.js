import { useCallback, useEffect, useMemo, useState } from 'react'
import { apiFetch } from '../../lib/api'
import { toast } from '../../lib/toast'
import { useAuth } from '../../auth/authContext'

export function useUtilisateursPage(fixedRole, search) {
  const { hasPermission, hasAnyPermission } = useAuth()
  
  const [roles, setRoles] = useState([])
  const [users, setUsers] = useState([])
  const [commandes, setCommandes] = useState([])
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState('')

  const [roleFilter, setRoleFilter] = useState(fixedRole || 'all')
  const [statusFilter, setStatusFilter] = useState('all')
  const [open, setOpen] = useState(false)
  const [modalMode, setModalMode] = useState('create')
  const [editing, setEditing] = useState(null)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [deleting, setDeleting] = useState(null)

  const loadAll = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const needCommandes = hasAnyPermission(['commandes.view', 'commandes.edit', 'commandes.cancel'])
      const needRoles = hasPermission('utilisateurs.manage') || hasPermission('systeme.settings')
      const reqs = [apiFetch('/api/utilisateurs?per_page=1000')]
      if (needRoles) reqs.unshift(apiFetch('/api/roles?per_page=1000'))
      if (needCommandes) reqs.push(apiFetch('/api/commandes_vente?per_page=1000'))
      const res = await Promise.all(reqs)
      const rolesRes = needRoles ? res[0] : null
      const usersRes = needRoles ? res[1] : res[0]
      const commandesRes = needCommandes ? res[res.length - 1] : null

      const r = rolesRes ? (Array.isArray(rolesRes?.data) ? rolesRes.data : rolesRes?.data?.data || []) : []
      const u = Array.isArray(usersRes?.data) ? usersRes.data : usersRes?.data?.data || []
      const c = commandesRes ? (Array.isArray(commandesRes?.data) ? commandesRes.data : commandesRes?.data?.data || []) : []
      setRoles(r)
      setUsers(u)
      setCommandes(c)
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setLoading(false)
    }
  }, [hasAnyPermission, hasPermission])

  useEffect(() => {
    if (!hasAnyPermission(['utilisateurs.view', 'utilisateurs.manage'])) return
    loadAll()
  }, [hasAnyPermission, loadAll])

  const allowedRoles = useMemo(() => {
    const allowed = new Set(['agent'])
    return roles.filter((r) => allowed.has((r?.nom || '').toString().toLowerCase()))
  }, [roles])

  const allowedRoleByName = useMemo(() => {
    const map = new Map()
    for (const r of allowedRoles) map.set((r?.nom || '').toString().toLowerCase(), r)
    return map
  }, [allowedRoles])

  useEffect(() => {
    if (!fixedRole) return
    setRoleFilter(fixedRole)
  }, [fixedRole])

  const filteredUsers = useMemo(() => {
    const q = search.trim().toLowerCase()
    const filter = (roleFilter || 'all').toString().toLowerCase()
    const allowedIds = new Set(allowedRoles.map((r) => String(r.id)))
    const status = (statusFilter || 'all').toString().toLowerCase()

    return users
      .filter((u) => allowedIds.has(String(u?.role_id ?? u?.role?.id ?? '')))
      .filter((u) => {
        const roleName = (u?.role?.nom || '').toString().toLowerCase()
        if (filter === 'all') return true
        return roleName === filter
      })
      .filter((u) => {
        if (status === 'all') return true
        return status === 'actif' ? !!u.actif : !u.actif
      })
      .filter((u) => {
        if (!q) return true
        const name = `${u?.nom || ''} ${u?.prenom || ''}`.toLowerCase()
        const mail = (u?.email || '').toString().toLowerCase()
        return name.includes(q) || mail.includes(q)
      })
  }, [users, allowedRoles, roleFilter, search, statusFilter])

  const statsByUserId = useMemo(() => {
    const map = new Map()
    for (const cmd of commandes) {
      const uid = cmd?.utilisateur_id != null ? String(cmd.utilisateur_id) : ''
      if (!uid) continue
      const cur = map.get(uid) || { count: 0, total: 0 }
      cur.count += 1
      cur.total += Number(cmd?.total ?? 0)
      map.set(uid, cur)
    }
    return map
  }, [commandes])

  const csvData = useMemo(() => {
    return filteredUsers.map((u) => {
      const s = statsByUserId.get(String(u.id)) || { count: 0, total: 0 }
      return {
        nom: `${u.nom || ''} ${u.prenom || ''}`.trim(),
        email: u.email,
        role: u?.role?.nom || '',
        actif: u.actif ? 'oui' : 'non',
        commandes: s.count,
        total: s.total,
      }
    })
  }, [filteredUsers, statsByUserId])

  function openCreate() {
    setModalMode('create')
    setEditing(null)
    const fallbackRole = fixedRole && allowedRoleByName.get(String(fixedRole).toLowerCase())?.id
    setOpen(true)
    if (fallbackRole) setEditing({ role_id: fallbackRole })
  }

  function openEdit(u) {
    setModalMode('edit')
    setEditing(u)
    setOpen(true)
  }

  function askDelete(u) {
    setDeleting(u)
    setConfirmOpen(true)
  }

  async function submit(payload) {
    setSubmitting(true)
    setError('')
    try {
      const body = { ...payload }
      if (body.mot_de_passe == null) delete body.mot_de_passe

      if (modalMode === 'edit' && editing?.id) {
        await apiFetch(`/api/utilisateurs/${editing.id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        })
        toast({ type: 'success', message: 'Utilisateur mis à jour.' })
      } else {
        await apiFetch('/api/utilisateurs', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        })
        toast({ type: 'success', message: 'Utilisateur ajouté.' })
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
      await apiFetch(`/api/utilisateurs/${deleting.id}`, { method: 'DELETE' })
      toast({ type: 'success', message: 'Utilisateur supprimé.' })
      setConfirmOpen(false)
      setDeleting(null)
      await loadAll()
    } catch (e) {
      setError(e?.message || 'Erreur')
      toast({ type: 'error', message: e?.message || 'Erreur' })
    } finally {
      setSubmitting(false)
    }
  }

  async function toggleActive(u) {
    if (!u?.id) return
    const next = !u.actif
    setUsers((prev) => prev.map((x) => (x.id === u.id ? { ...x, actif: next } : x)))
    try {
      await apiFetch(`/api/utilisateurs/${u.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ actif: next }),
      })
      toast({ type: 'success', message: next ? 'Utilisateur activé.' : 'Utilisateur désactivé.' })
    } catch (e) {
      setUsers((prev) => prev.map((x) => (x.id === u.id ? { ...x, actif: !next } : x)))
      toast({ type: 'error', message: e?.message || 'Erreur' })
    }
  }

  return {
    hasPermission,
    hasAnyPermission,
    loading,
    error,
    submitting,
    roles,
    users,
    filteredUsers,
    allowedRoles,
    roleFilter,
    setRoleFilter,
    statusFilter,
    setStatusFilter,
    open,
    setOpen,
    modalMode,
    editing,
    setEditing,
    confirmOpen,
    setConfirmOpen,
    deleting,
    setDeleting,
    csvData,
    statsByUserId,
    openCreate,
    openEdit,
    askDelete,
    submit,
    confirmDelete,
    toggleActive,
  }
}
