import { useEffect, useMemo, useRef, useState } from 'react'
import { Pencil, Plus, Trash2, X, Tag } from 'lucide-react'
import { apiFetch } from '../../lib/api'
import Alert from '../../components/Alert'
import '../../styles/categories.css'

export function MarqueModal({ open, mode = 'create', initialValues, onClose, onSubmit }) {
  const [nom, setNom] = useState(() => initialValues?.nom ?? '')
  const [file, setFile] = useState(null)

  useEffect(() => {
    if (open) {
      setNom(initialValues?.nom ?? '')
      setFile(null)
    }
  }, [open, initialValues])

  if (!open) return null

  function submit(e) {
    e.preventDefault()
    if (!nom.trim()) return
    onSubmit({ nom: nom.trim(), file })
  }

  return (
    <div className="modal-overlay" onMouseDown={onClose}>
      <div className="modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-title">{mode === 'edit' ? 'Modifier la Marque' : 'Ajouter une Marque'}</div>
          <button className="modal-x" type="button" onClick={onClose} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>
        <form className="modal-body" onSubmit={submit}>
          <label className="form-label">
            Nom de la Marque
            <input className="form-input" value={nom} onChange={(e) => setNom(e.target.value)} placeholder="Ex: Samsung, Apple..." />
          </label>
          {mode === 'edit' && initialValues?.image ? (
            <div className="cat-image-preview">
              <img src={initialValues.image_url || initialValues.image} alt={initialValues.nom} />
            </div>
          ) : null}
          <label className="form-label">
            Logo / Image
            <input className="form-input" type="file" accept="image/*" onChange={(e) => setFile(e.target.files?.[0] || null)} />
          </label>
          <div className="modal-foot">
            <button className="btn-ghost" type="button" onClick={onClose}>
              Annuler
            </button>
            <button className="btn-primary" type="submit" disabled={!nom.trim()}>
              {mode === 'edit' ? 'Enregistrer' : 'Ajouter'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default function Marques() {
  const [open, setOpen] = useState(false)
  const [editOpen, setEditOpen] = useState(false)
  const [editing, setEditing] = useState(null)

  const [marques, setMarques] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const errTimerRef = useRef(null)

  function showTempError(message) {
    setError(message)
    if (errTimerRef.current) window.clearTimeout(errTimerRef.current)
    errTimerRef.current = window.setTimeout(() => setError(''), 3800)
  }

  async function load() {
    setLoading(true)
    try {
      const res = await apiFetch('/api/marques?per_page=1000')
      setMarques(Array.isArray(res?.data) ? res.data : res?.data?.data || [])
    } catch (e) {
      setError(e?.message || 'Erreur lors du chargement')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
  }, [])

  async function addMarque(values) {
    const form = new FormData()
    form.append('nom', values.nom)
    if (values.file) form.append('image', values.file)

    try {
      await apiFetch('/api/marques', {
        method: 'POST',
        body: form,
      })
      setOpen(false)
      await load()
    } catch (e) {
      showTempError(e?.message || 'Erreur')
    }
  }

  async function updateMarque(values) {
    if (!editing?.id) return
    const form = new FormData()
    form.append('_method', 'PUT')
    form.append('nom', values.nom)
    if (values.file) form.append('image', values.file)

    try {
      await apiFetch(`/api/marques/${editing.id}`, {
        method: 'POST', // Use POST with _method=PUT for multipart/form-data
        body: form,
      })
      setEditOpen(false)
      setEditing(null)
      await load()
    } catch (e) {
      showTempError(e?.message || 'Erreur')
    }
  }

  async function deleteMarque(id) {
    if (!window.confirm('Voulez-vous vraiment supprimer cette marque ?')) return
    try {
      await apiFetch(`/api/marques/${id}`, { method: 'DELETE' })
      await load()
    } catch (e) {
      showTempError(e?.message || 'Erreur')
    }
  }

  return (
    <section className="content">
      <div className="page-head">
        <div>
          <div className="page-title page-title-xl">Gestion des Marques</div>
          <div className="page-subtitle">Gérer les marques de vos produits</div>
        </div>
        <button className="primary primary-pill" type="button" onClick={() => setOpen(true)}>
          <Plus size={16} />
          Ajouter une Marque
        </button>
      </div>

      <Alert type="error" message={error} />

      <div className="cat-grid">
        {loading ? <div className="products-empty">Chargement...</div> : null}
        {!loading && marques.length === 0 ? <div className="products-empty">Aucune marque trouvée</div> : null}
        
        {!loading && marques.map((m) => (
          <div key={m.id} className="cat-card">
            <div className="cat-top">
              <div className="cat-ico">
                {m.image ? (
                  <img className="cat-img" src={m.image_url || m.image} alt={m.nom} />
                ) : (
                  <div className="cat-img-fallback">{m.nom[0]}</div>
                )}
              </div>
              <div>
                <div className="cat-name">{m.nom}</div>
                <div className="cat-count">Marque de produit</div>
              </div>
            </div>

            <div className="cat-actions">
              <button
                className="cat-btn"
                type="button"
                onClick={() => {
                  setEditing(m)
                  setEditOpen(true)
                }}
              >
                <Pencil size={16} />
                Modifier
              </button>
              <button className="cat-icon-btn cat-icon-btn-danger" type="button" onClick={() => deleteMarque(m.id)}>
                <Trash2 size={16} />
              </button>
            </div>
          </div>
        ))}
      </div>

      <MarqueModal open={open} mode="create" onClose={() => setOpen(false)} onSubmit={addMarque} />
      <MarqueModal
        open={editOpen}
        mode="edit"
        initialValues={editing}
        onClose={() => {
          setEditOpen(false)
          setEditing(null)
        }}
        onSubmit={updateMarque}
      />
    </section>
  )
}
