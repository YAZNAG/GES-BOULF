import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { FolderTree, Pencil, Plus, Trash2, X } from 'lucide-react'
import { apiFetch } from '../../lib/api'
import Alert from '../../components/Alert'
import ConfirmDialog from '../../components/ConfirmDialog'
import '../../styles/categories.css'

function FamilleModal({ open, mode = 'create', initialValues, onClose, onSubmit }) {
  const [nomAr, setNomAr] = useState('')
  const [nomFr, setNomFr] = useState('')
  const [file, setFile] = useState(null)
  const [preview, setPreview] = useState(null)

  useEffect(() => {
    if (open) {
      setNomAr(initialValues?.nom_ar ?? '')
      setNomFr(initialValues?.nom_fr ?? '')
      setFile(null)
      setPreview(initialValues?.image ?? null)
    }
  }, [open, initialValues])

  useEffect(() => {
    if (!file) return
    const objectUrl = URL.createObjectURL(file)
    setPreview(objectUrl)
    return () => URL.revokeObjectURL(objectUrl)
  }, [file])

  if (!open) return null

  function submit(e) {
    e.preventDefault()
    if (!(nomAr.trim() || nomFr.trim())) return

    onSubmit({
      nom_ar: nomAr.trim(),
      nom_fr: nomFr.trim(),
      file,
    })
  }

  return (
    <div className="modal-overlay" onMouseDown={onClose}>
      <div className="modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-title">
            {mode === 'edit' ? 'Modifier une Famille' : 'Ajouter une Famille'}
          </div>

          <button className="modal-x" type="button" onClick={onClose} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>

        <form className="modal-body" onSubmit={submit}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <label className="form-label">
              Nom Français
              <input
                className="form-input"
                value={nomFr}
                onChange={(e) => setNomFr(e.target.value)}
                placeholder="Ex: Produits Alimentaires"
              />
            </label>

            <label className="form-label">
              Nom Arabe
              <input
                className="form-input"
                value={nomAr}
                onChange={(e) => setNomAr(e.target.value)}
                placeholder="مثال: المنتجات الغذائية"
                dir="rtl"
              />
            </label>
          </div>

          {preview ? (
            <div className="cat-ico" style={{ marginBottom: '12px' }}>
              <img className="cat-img" src={preview} alt="Aperçu famille" />
            </div>
          ) : null}

          <label className="form-label">
            Image
            <input
              className="form-input"
              type="file"
              accept="image/*"
              onChange={(e) => setFile(e.target.files?.[0] || null)}
            />
          </label>

          <div className="modal-foot">
            <button className="btn-ghost" type="button" onClick={onClose}>
              Annuler
            </button>

            <button
              className="btn-primary"
              type="submit"
              disabled={!(nomAr.trim() || nomFr.trim())}
            >
              {mode === 'edit' ? 'Enregistrer' : 'Ajouter'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default function Familles() {
  const navigate = useNavigate()
  const [open, setOpen] = useState(false)
  const [editOpen, setEditOpen] = useState(false)
  const [editing, setEditing] = useState(null)

  const [familles, setFamilles] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [toDelete, setToDelete] = useState(null)
  const errTimerRef = useRef(null)

  function showTempError(message) {
    const msg = (message || '').toString()
    if (!msg) return
    setError(msg)
    if (errTimerRef.current) window.clearTimeout(errTimerRef.current)
    errTimerRef.current = window.setTimeout(() => setError(''), 3800)
  }

  async function load() {
    setError('')
    setLoading(true)

    try {
      const res = await apiFetch('/api/familles')
      const items = Array.isArray(res) ? res : res?.data || []

      setFamilles(items)
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
  }, [])

  useEffect(() => {
    return () => {
      if (errTimerRef.current) window.clearTimeout(errTimerRef.current)
    }
  }, [])

  const totals = useMemo(() => {
    const totalFamilles = familles.length
    return { totalFamilles }
  }, [familles])

  async function addFamille(values) {
    try {
      const form = new FormData()
      form.append('nom_ar', values.nom_ar)
      form.append('nom_fr', values.nom_fr)
      if (values.file) form.append('image', values.file)

      await apiFetch('/api/familles', { method: 'POST', body: form })
      setOpen(false)
      await load()
    } catch (e) {
      showTempError(e?.message || 'Erreur')
    }
  }

  async function updateFamille(values) {
    if (!editing?.id) return

    try {
      const form = new FormData()
      form.append('_method', 'PUT')
      form.append('nom_ar', values.nom_ar)
      form.append('nom_fr', values.nom_fr)
      if (values.file) form.append('image', values.file)

      await apiFetch(`/api/familles/${editing.id}`, { method: 'POST', body: form })
      setEditOpen(false)
      setEditing(null)
      await load()
    } catch (e) {
      showTempError(e?.message || 'Erreur')
    }
  }

  function askDelete(famille) {
    setToDelete(famille)
    setConfirmOpen(true)
  }

  async function confirmDelete() {
    if (!toDelete) return
    setConfirmOpen(false)
    try {
      await apiFetch(`/api/familles/${toDelete.id}`, { method: 'DELETE' })
      setToDelete(null)
      await load()
    } catch (e) {
      showTempError(e?.message || 'Erreur')
    }
  }

  return (
    <section className="content">
      <div className="page-head">
        <div>
          <div className="page-title page-title-xl">Familles</div>
          <div className="page-subtitle">Gérer les familles de produits</div>
        </div>

        <button className="primary primary-pill" type="button" onClick={() => setOpen(true)}>
          <Plus size={16} />
          Ajouter Famille
        </button>
      </div>

      <Alert type="error" message={error} />

      <div className="cat-grid">
        {loading ? <div className="products-empty">Chargement…</div> : null}

        {!loading &&
          familles.map((f) => (
            <div key={f.id} className="cat-card">
              <div className="cat-top">
                <div className="cat-ico">
                  {f.image ? (
                    <img className="cat-img" src={f.image} alt={f.nom_fr || f.nom_ar} />
                  ) : (
                    <div className="cat-img-fallback">{(f.nom_fr || f.nom_ar || '?')[0]}</div>
                  )}
                </div>

                <div>
                  <div className="cat-name">{f.nom_ar || f.nom_fr}</div>

                  {(f.nom_ar && f.nom_fr) && (
                    <div style={{ fontSize: '11px', color: '#64748b' }}>
                      {f.nom_ar} | {f.nom_fr}
                    </div>
                  )}

                  <div className="cat-count">Famille</div>
                </div>
              </div>

              <div className="cat-actions">
                <button
                  className="cat-btn"
                  type="button"
                  onClick={() => {
                    setEditing(f)
                    setEditOpen(true)
                  }}
                >
                  <Pencil size={16} />
                  Modifier
                </button>

                <button
                  className="cat-icon-btn"
                  type="button"
                  onClick={() => navigate(`/admin/familles/${f.id}/categories`)}
                  aria-label="Catégories"
                >
                  <FolderTree size={16} />
                </button>

                <button
                  className="cat-icon-btn cat-icon-btn-danger"
                  type="button"
                  onClick={() => askDelete(f)}
                  aria-label="Supprimer"
                >
                  <Trash2 size={16} />
                </button>
              </div>
            </div>
          ))}
      </div>

      <FamilleModal
        open={open}
        mode="create"
        onClose={() => setOpen(false)}
        onSubmit={addFamille}
      />

      <FamilleModal
        open={editOpen}
        mode="edit"
        initialValues={editing}
        onClose={() => {
          setEditOpen(false)
          setEditing(null)
        }}
        onSubmit={updateFamille}
      />

      <ConfirmDialog
        open={confirmOpen}
        title="Supprimer la famille"
        message={`Voulez-vous vraiment supprimer la famille « ${toDelete?.nom_fr || toDelete?.nom_ar} » ? Cette action est irréversible.`}
        confirmLabel="Supprimer"
        onConfirm={confirmDelete}
        onCancel={() => {
          setConfirmOpen(false)
          setToDelete(null)
        }}
      />
    </section>
  )
}