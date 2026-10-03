import { useCallback, useEffect, useMemo, useState } from 'react'
import { toast } from '../../lib/toast'
import { deleteCommandeVente, fetchClients, fetchCommandesVente, updateCommandeVente } from './api'

function normalizeStatut(value) {
  const rawStatut = (value || '').toString()
  const s = rawStatut.toLowerCase()
  if (s.includes('pay') || s.includes('livr')) return 'payée'
  if (s.includes('confirm')) return 'confirmée'
  if (s.includes('annul')) return 'annulée'
  return 'en_attente'
}

export function useCommandesPage(searchQuery) {
  const [commandes, setCommandes] = useState([])
  const [clients, setClients] = useState([])
  const [loading, setLoading] = useState(true)

  const [statusFilter, setStatusFilter] = useState('')
  const [typeFilter, setTypeFilter] = useState('')

  const [viewModalOpen, setViewModalOpen] = useState(false)
  const [editModalOpen, setEditModalOpen] = useState(false)
  const [deleteModalOpen, setDeleteModalOpen] = useState(false)

  const [selectedCommande, setSelectedCommande] = useState(null)

  const [editForm, setEditForm] = useState({
    client_id: '',
    type_commande: 'livraison',
    statut: '',
    total: '',
  })

  const reload = useCallback(async () => {
    setLoading(true)
    try {
      const data = await fetchCommandesVente()
      setCommandes(Array.isArray(data) ? data : [])
    } catch (error) {
      toast({ type: 'error', message: error?.message || 'Erreur de chargement des commandes.' })
    } finally {
      setLoading(false)
    }
  }, [])

  const reloadClients = useCallback(async () => {
    try {
      const data = await fetchClients()
      setClients(Array.isArray(data) ? data : [])
    } catch (error) {
      toast({ type: 'error', message: error?.message || 'Erreur de chargement des clients.' })
    }
  }, [])

  useEffect(() => {
    reload()
    reloadClients()
  }, [reload, reloadClients])

  const handleView = useCallback((cmd) => {
    setSelectedCommande(cmd)
    setViewModalOpen(true)
  }, [])

  const handleEdit = useCallback((cmd) => {
    setSelectedCommande(cmd)
    setEditForm({
      client_id: cmd?.client_id || '',
      type_commande: (cmd?.type_commande || 'livraison').toString().toLowerCase() === 'retrait' ? 'retrait' : 'livraison',
      statut: normalizeStatut(cmd?.statut),
      total: cmd?.total || 0,
    })
    setEditModalOpen(true)
  }, [])

  const handleDelete = useCallback((cmd) => {
    setSelectedCommande(cmd)
    setDeleteModalOpen(true)
  }, [])

  const submitEdit = useCallback(async () => {
    try {
      await updateCommandeVente(selectedCommande.id, {
        client_id: editForm.client_id === '' ? null : Number(editForm.client_id),
        type_commande: (editForm.type_commande || 'livraison').toString().toLowerCase() === 'retrait' ? 'retrait' : 'livraison',
        statut: (editForm.statut || '').toString(),
        total: editForm.total === '' ? 0 : Number(editForm.total),
      })
      setEditModalOpen(false)
      await reload()
      toast({ type: 'success', message: 'Commande mise à jour.' })
    } catch (error) {
      toast({ type: 'error', message: error?.message || 'Impossible de modifier la commande.' })
    }
  }, [editForm.client_id, editForm.statut, editForm.total, editForm.type_commande, reload, selectedCommande?.id])

  const confirmDelete = useCallback(async () => {
    try {
      await deleteCommandeVente(selectedCommande.id)
      setDeleteModalOpen(false)
      await reload()
      toast({ type: 'success', message: 'Commande supprimée.' })
    } catch (error) {
      toast({ type: 'error', message: error?.message || 'Impossible de supprimer la commande.' })
    }
  }, [reload, selectedCommande?.id])

  const formatDate = useCallback((dateString) => {
    if (!dateString) return ''
    const d = new Date(dateString)
    const pad = (n) => n.toString().padStart(2, '0')
    return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`
  }, [])

  const getStatusBadge = useCallback((status) => {
    let className = 'status-badge '
    let label = status
    const s = (status || '').toLowerCase()
    if (s.includes('cours') || s.includes('attente')) {
      className += 'status-en-cours'
      label = 'En cours'
    } else if (s.includes('livr') || s.includes('pay')) {
      className += 'status-livre'
      label = 'Livré'
    } else if (s.includes('annul')) {
      className += 'status-annule'
      label = 'Annulé'
    } else {
      className += 'status-default'
    }
    return (<span className={className}>{label}</span>)
  }, [])

  const getTypeBadge = useCallback((type) => {
    const t = (type || 'livraison').toLowerCase()
    const label = t === 'retrait' ? 'Retrait' : 'Livraison'
    return <span className="type-badge">{label}</span>
  }, [])

  const filteredCommandes = useMemo(() => {
    const q = (searchQuery || '').trim().toLowerCase()
    return commandes.filter((cmd) => {
      const numero = (cmd?.numero || '').toString().toLowerCase()
      const clientNom = (cmd?.client?.nom || '').toString().toLowerCase()

      const matchesSearch = q === '' || numero.includes(q) || clientNom.includes(q)

      const matchesStatus =
        statusFilter === '' ||
        (statusFilter === 'En cours' && (cmd.statut === 'en_attente' || cmd.statut === 'En cours')) ||
        (statusFilter === 'Livré' && (cmd.statut === 'payée' || cmd.statut === 'Livré')) ||
        (statusFilter === 'Annulé' && (cmd.statut === 'annulée' || cmd.statut === 'Annulé'))

      const matchesType =
        typeFilter === '' ||
        (cmd?.type_commande || '').toString().toLowerCase() === typeFilter.toLowerCase()

      return matchesSearch && matchesStatus && matchesType
    })
  }, [commandes, searchQuery, statusFilter, typeFilter])

  return {
    loading,
    clients,
    filteredCommandes,

    statusFilter,
    setStatusFilter,
    typeFilter,
    setTypeFilter,

    viewModalOpen,
    setViewModalOpen,
    editModalOpen,
    setEditModalOpen,
    deleteModalOpen,
    setDeleteModalOpen,
    selectedCommande,
    editForm,
    setEditForm,

    handleView,
    handleEdit,
    handleDelete,
    submitEdit,
    confirmDelete,
    formatDate,
    getStatusBadge,
    getTypeBadge,
  }
}

