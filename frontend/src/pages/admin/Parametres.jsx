import { useEffect, useMemo, useState } from 'react'
import { Settings, CreditCard, Bell, Boxes, Plus, Pencil, Tag, Trash2, X } from 'lucide-react'
import { useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../../auth/authContext'
import { apiFetch } from '../../lib/api'
import Alert from '../../components/Alert'
import { ConfirmModal } from '../../components/ConfirmModal'
import { useParametres } from '../../features/parametres/useParametres'
import { GeneralSettings } from '../../components/Parametres/GeneralSettings'
import { BillingSettings } from '../../components/Parametres/BillingSettings'
import { NotificationSettings } from '../../components/Parametres/NotificationSettings'

import Marques from './Marques'
import '../../styles/parametres.css'

function UniteModal({ open, mode = 'create', submitting, initialValues, onClose, onSubmit }) {
  const [nom, setNom] = useState(() => initialValues?.nom ?? '')
  const [description, setDescription] = useState(() => initialValues?.description ?? '')
  const [actif, setActif] = useState(() => initialValues?.actif ?? true)

  if (!open) return null

  function submit(e) {
    e.preventDefault()
    const nextNom = nom.trim()
    if (!nextNom) return
    onSubmit?.({
      nom: nextNom,
      description: description.trim() || null,
      actif: !!actif,
    })
  }

  return (
    <div className="modal-overlay" onMouseDown={onClose}>
      <div className="modal modal-premium" onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-head-main">
            <div className="modal-icon-bg">
              <Boxes size={20} />
            </div>
            <div>
              <div className="modal-title">{mode === 'edit' ? 'Modifier l’unité' : 'Ajouter une unité'}</div>
              <div className="modal-subtitle">Gérez les unités de mesure de vos produits</div>
            </div>
          </div>
          <button className="modal-x" type="button" onClick={onClose} aria-label="Fermer" disabled={submitting}>
            <X size={20} />
          </button>
        </div>
        <form className="modal-body" onSubmit={submit}>
          <div className="form-group">
            <label className="form-label">Nom de l'unité</label>
            <input 
              className="form-input" 
              value={nom} 
              onChange={(e) => setNom(e.target.value)} 
              placeholder="Ex: Pièce, Kg, Litre..." 
              required
            />
          </div>
          
          <div className="form-group">
            <label className="form-label">Description (Optionnel)</label>
            <input
              className="form-input"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Détails supplémentaires..."
            />
          </div>

          <div className="form-group">
            <label className="form-label">Statut</label>
            <div className="select-wrapper">
              <select className="form-input" value={actif ? '1' : '0'} onChange={(e) => setActif(e.target.value === '1')}>
                <option value="1">Actif</option>
                <option value="0">Inactif</option>
              </select>
            </div>
          </div>

          <div className="modal-foot">
            <button className="btn-ghost" type="button" onClick={onClose} disabled={submitting}>
              Annuler
            </button>
            <button className="btn-primary" type="submit" disabled={submitting || !nom.trim()}>
              {submitting ? 'Traitement...' : (mode === 'edit' ? 'Enregistrer les modifications' : 'Ajouter l’unité')}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

function UnitesSettings() {
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [open, setOpen] = useState(false)
  const [mode, setMode] = useState('create')
  const [editing, setEditing] = useState(null)
  const [submitting, setSubmitting] = useState(false)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [deleting, setDeleting] = useState(null)

  async function load() {
    setLoading(true)
    setError('')
    try {
      const res = await apiFetch('/api/unites?per_page=1000')
      const list = Array.isArray(res?.data) ? res.data : res?.data?.data || []
      setItems(list)
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
  }, [])

  const sorted = useMemo(() => {
    return [...items].sort((a, b) => String(a?.nom || '').localeCompare(String(b?.nom || '')))
  }, [items])

  function openCreate() {
    setMode('create')
    setEditing(null)
    setOpen(true)
  }

  function openEdit(u) {
    setMode('edit')
    setEditing(u)
    setOpen(true)
  }

  function askDelete(u) {
    setDeleting(u)
    setConfirmOpen(true)
  }

  async function submit(values) {
    setSubmitting(true)
    setError('')
    try {
      if (mode === 'edit' && editing?.id) {
        await apiFetch(`/api/unites/${editing.id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(values),
        })
      } else {
        await apiFetch('/api/unites', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(values),
        })
      }
      setOpen(false)
      setEditing(null)
      await load()
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setSubmitting(false)
    }
  }

  async function confirmDelete() {
    if (!deleting?.id) return
    setSubmitting(true)
    setError('')
    try {
      await apiFetch(`/api/unites/${deleting.id}`, { method: 'DELETE' })
      setConfirmOpen(false)
      setDeleting(null)
      await load()
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div>
      <div className="units-head">
        <div className="param-section-title" style={{ marginBottom: 0 }}>
          Unités
        </div>
        <button className="primary primary-pill" type="button" onClick={openCreate}>
          <Plus size={16} />
          Ajouter Unité
        </button>
      </div>

      <Alert type="error" message={error} />

      {loading ? <div style={{ padding: '20px', color: '#64748b' }}>Chargement…</div> : null}
      {!loading && sorted.length === 0 ? <div style={{ padding: '20px', color: '#64748b' }}>Aucune unité</div> : null}

      {!loading && sorted.length ? (
        <div className="units-list">
          {sorted.map((u) => (
            <div key={u.id} className="units-row">
              <div className="units-main">
                <div className="units-name">{u.nom}</div>
                {u.description ? <div className="units-desc">{u.description}</div> : null}
              </div>
              <div className="units-right">
                <div className={u.actif ? 'badge badge-success' : 'badge badge-secondary'}>{u.actif ? 'Actif' : 'Inactif'}</div>
                <button className="icon-pill" type="button" onClick={() => openEdit(u)} aria-label="Modifier">
                  <Pencil size={16} />
                </button>
                <button className="icon-pill icon-pill-danger" type="button" onClick={() => askDelete(u)} aria-label="Supprimer">
                  <Trash2 size={16} />
                </button>
              </div>
            </div>
          ))}
        </div>
      ) : null}

      <UniteModal
        key={`${mode}-${open ? '1' : '0'}-${editing?.id || 'new'}`}
        open={open}
        mode={mode}
        submitting={submitting}
        initialValues={mode === 'edit' ? editing : null}
        onClose={() => {
          if (submitting) return
          setOpen(false)
          setEditing(null)
        }}
        onSubmit={submit}
      />

      <ConfirmModal
        open={confirmOpen}
        title="Supprimer l’unité"
        description={`Voulez-vous supprimer "${deleting?.nom || ''}" ?`}
        onClose={() => {
          if (submitting) return
          setConfirmOpen(false)
          setDeleting(null)
        }}
        onConfirm={confirmDelete}
        confirmLabel="Supprimer"
        disabled={submitting}
      />
    </div>
  )
}


function ModePaiementModal({ open, mode = 'create', submitting, initialValues, onClose, onSubmit }) {
  const [nom, setNom] = useState(() => initialValues?.nom ?? '')
  const [actif, setActif] = useState(() => initialValues?.actif ?? true)

  if (!open) return null

  function submit(e) {
    e.preventDefault()
    const nextNom = nom.trim()
    if (!nextNom) return
    onSubmit?.({
      nom: nextNom,
      actif: !!actif,
    })
  }

  return (
    <div className="modal-overlay" onMouseDown={onClose}>
      <div className="modal modal-premium" onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-head-main">
            <div className="modal-icon-bg">
              <CreditCard size={20} />
            </div>
            <div>
              <div className="modal-title">{mode === 'edit' ? 'Modifier le mode' : 'Ajouter un mode'}</div>
              <div className="modal-subtitle">Gérez les modes de paiement acceptés</div>
            </div>
          </div>
          <button className="modal-x" type="button" onClick={onClose} aria-label="Fermer" disabled={submitting}>
            <X size={20} />
          </button>
        </div>
        <form className="modal-body" onSubmit={submit}>
          <div className="form-group">
            <label className="form-label">Nom du mode de paiement</label>
            <input 
              className="form-input" 
              value={nom} 
              onChange={(e) => setNom(e.target.value)} 
              placeholder="Ex: Espèces, Carte, Chèque..." 
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label">Statut</label>
            <div className="select-wrapper">
              <select className="form-input" value={actif ? '1' : '0'} onChange={(e) => setActif(e.target.value === '1')}>
                <option value="1">Actif</option>
                <option value="0">Inactif</option>
              </select>
            </div>
          </div>

          <div className="modal-foot">
            <button className="btn-ghost" type="button" onClick={onClose} disabled={submitting}>
              Annuler
            </button>
            <button className="btn-primary" type="submit" disabled={submitting || !nom.trim()}>
              {submitting ? 'Traitement...' : (mode === 'edit' ? 'Enregistrer les modifications' : 'Ajouter le mode')}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

function ModesPaiementSettings() {
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [open, setOpen] = useState(false)
  const [mode, setMode] = useState('create')
  const [editing, setEditing] = useState(null)
  const [submitting, setSubmitting] = useState(false)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [deleting, setDeleting] = useState(null)

  async function load() {
    setLoading(true)
    setError('')
    try {
      const res = await apiFetch('/api/mode_paiements?per_page=1000')
      const list = Array.isArray(res?.data) ? res.data : res?.data?.data || []
      setItems(list)
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
  }, [])

  const sorted = useMemo(() => {
    return [...items].sort((a, b) => String(a?.nom || '').localeCompare(String(b?.nom || '')))
  }, [items])

  function openCreate() {
    setMode('create')
    setEditing(null)
    setOpen(true)
  }

  function openEdit(u) {
    setMode('edit')
    setEditing(u)
    setOpen(true)
  }

  function askDelete(u) {
    setDeleting(u)
    setConfirmOpen(true)
  }

  async function submit(values) {
    setSubmitting(true)
    setError('')
    try {
      if (mode === 'edit' && editing?.id) {
        await apiFetch(`/api/mode_paiements/${editing.id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(values),
        })
      } else {
        await apiFetch('/api/mode_paiements', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(values),
        })
      }
      setOpen(false)
      setEditing(null)
      await load()
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setSubmitting(false)
    }
  }

  async function confirmDelete() {
    if (!deleting?.id) return
    setSubmitting(true)
    setError('')
    try {
      await apiFetch(`/api/mode_paiements/${deleting.id}`, { method: 'DELETE' })
      setConfirmOpen(false)
      setDeleting(null)
      await load()
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div>
      <div className="units-head">
        <div className="param-section-title" style={{ marginBottom: 0 }}>
          Modes de Paiement
        </div>
        <button className="primary primary-pill" type="button" onClick={openCreate}>
          <Plus size={16} />
          Ajouter Mode
        </button>
      </div>

      <Alert type="error" message={error} />

      {loading ? <div style={{ padding: '20px', color: '#64748b' }}>Chargement…</div> : null}
      {!loading && sorted.length === 0 ? <div style={{ padding: '20px', color: '#64748b' }}>Aucun mode de paiement</div> : null}

      {!loading && sorted.length ? (
        <div className="units-list">
          {sorted.map((u) => (
            <div key={u.id} className="units-row">
              <div className="units-main">
                <div className="units-name">{u.nom}</div>
              </div>
              <div className="units-right">
                <div className={u.actif ? 'badge badge-success' : 'badge badge-secondary'}>{u.actif ? 'Actif' : 'Inactif'}</div>
                <button className="icon-pill" type="button" onClick={() => openEdit(u)} aria-label="Modifier">
                  <Pencil size={16} />
                </button>
                <button className="icon-pill icon-pill-danger" type="button" onClick={() => askDelete(u)} aria-label="Supprimer">
                  <Trash2 size={16} />
                </button>
              </div>
            </div>
          ))}
        </div>
      ) : null}

      <ModePaiementModal
        key={`${mode}-${open ? '1' : '0'}-${editing?.id || 'new'}`}
        open={open}
        mode={mode}
        submitting={submitting}
        initialValues={mode === 'edit' ? editing : null}
        onClose={() => {
          if (submitting) return
          setOpen(false)
          setEditing(null)
        }}
        onSubmit={submit}
      />

      <ConfirmModal
        open={confirmOpen}
        title="Supprimer le mode"
        description={`Voulez-vous supprimer "${deleting?.nom || ''}" ?`}
        onClose={() => {
          if (submitting) return
          setConfirmOpen(false)
          setDeleting(null)
        }}
        onConfirm={confirmDelete}
        confirmLabel="Supprimer"
        disabled={submitting}
      />
    </div>
  )
}

export default function Parametres() {
  const { hasAnyPermission } = useAuth()
  const { settings, updateSettings, loading, submitting } = useParametres()
  const location = useLocation()
  const navigate = useNavigate()

  const initialTab = useMemo(() => {
    const tab = new URLSearchParams(location.search).get('tab')
    return tab || 'general'
  }, [location.search])
  const activeTab = initialTab

  if (!hasAnyPermission(['systeme.settings'])) {
    return (
      <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>
        Vous n&apos;avez pas la permission d&apos;accéder aux paramètres.
      </div>
    )
  }

  if (loading) {
    return <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>Chargement des paramètres...</div>
  }

  const tabs = [
    { id: 'general', label: 'Général', icon: Settings },
    { id: 'facturation', label: 'Facturation', icon: CreditCard },
    { id: 'notifications', label: 'Notifications', icon: Bell },
    { id: 'unites', label: 'Unités', icon: Boxes },
    { id: 'marques', label: 'Marques', icon: Tag },
    { id: 'paiement', label: 'Modes de Paiement', icon: CreditCard },
  ]

  return (
    <section className="content parametres-page">
      <div className="dash-head">
        <div>
          <div className="dash-title">Paramètres du système</div>
          <div className="dash-subtitle">
            <span className="dash-subtitle-dot" />
            Configuration globale de l&apos;application
          </div>
        </div>
      </div>

      <div className="param-layout">
        <aside className="param-sidebar">
          {tabs.map(tab => {
            const Icon = tab.icon
            return (
              <button
                key={tab.id}
                type="button"
                className={`param-tab ${activeTab === tab.id ? 'active' : ''}`}
                onClick={() => {
                  const params = new URLSearchParams(location.search)
                  params.set('tab', tab.id)
                  navigate({ pathname: location.pathname, search: params.toString() }, { replace: true })
                }}
              >
                <Icon size={18} />
                {tab.label}
              </button>
            )
          })}
        </aside>

        <div className="param-content">
          {activeTab === 'general' && (
            <GeneralSettings 
              key={`general-${JSON.stringify(settings || {})}`}
              settings={settings} 
              submitting={submitting} 
              onSave={updateSettings} 
            />
          )}

          {activeTab === 'facturation' && (
            <BillingSettings 
              key={`facturation-${JSON.stringify(settings || {})}`}
              settings={settings} 
              submitting={submitting} 
              onSave={updateSettings} 
            />
          )}

          {activeTab === 'notifications' && (
            <NotificationSettings 
              key={`notifications-${JSON.stringify(settings || {})}`}
              settings={settings} 
              submitting={submitting} 
              onSave={updateSettings} 
            />
          )}


          {activeTab === 'unites' && <UnitesSettings />}
          {activeTab === 'marques' && <Marques />}
          {activeTab === 'paiement' && <ModesPaiementSettings />}
        </div>
      </div>
    </section>
  )
}
