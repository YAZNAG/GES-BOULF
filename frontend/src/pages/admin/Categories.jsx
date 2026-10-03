import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { FolderTree, Pencil, Plus, Trash2, X } from 'lucide-react'
import { apiFetch } from '../../lib/api'
import Alert from '../../components/Alert'
import ConfirmDialog from '../../components/ConfirmDialog'
import '../../styles/categories.css'

const COUNT_KEY = 'gs_category_count'

function getMap(key) {
  const raw = localStorage.getItem(key)
  if (!raw) return {}
  try {
    return JSON.parse(raw)
  } catch {
    return {}
  }
}

function setMap(key, value) {
  localStorage.setItem(key, JSON.stringify(value))
}

function CategoryModal({ open, mode = 'create', initialValues, familles, onClose, onSubmit }) {
  const [nameAr, setNameAr] = useState('')
  const [nameFr, setNameFr] = useState('')
  const [familleId, setFamilleId] = useState('')
  const [file, setFile] = useState(null)
  const [preview, setPreview] = useState(null)

  useEffect(() => {
    if (open) {
      setNameAr(initialValues?.name_ar ?? '')
      setNameFr(initialValues?.name_fr ?? '')
      setFamilleId(initialValues?.famille_id ?? '')
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
    if (!(nameAr.trim() || nameFr.trim())) return
    if (mode !== 'edit' && !file) return

    const nom = nameFr.trim() || nameAr.trim() || 'Sans nom'

    onSubmit({
      name_ar: nameAr.trim(),
      name_fr: nameFr.trim(),
      nom,
      famille_id: familleId,
      file,
    })
  }

  return (
    <div className="modal-overlay" onMouseDown={onClose}>
      <div className="modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-title">
            {mode === 'edit' ? 'Modifier une Catégorie' : 'Ajouter une Catégorie'}
          </div>

          <button className="modal-x" type="button" onClick={onClose} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>

        <form className="modal-body" onSubmit={submit}>
          <label className="form-label">
            Famille
            <select
              className="form-input"
              value={familleId}
              onChange={(e) => setFamilleId(e.target.value)}
            >
              <option value="">Sélectionner une famille</option>
              {familles.map((f) => (
                <option key={f.id} value={f.id}>
                  {f.nom_fr || f.nom_ar}
                </option>
              ))}
            </select>
          </label>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <label className="form-label">
              Nom Français
              <input
                className="form-input"
                value={nameFr}
                onChange={(e) => setNameFr(e.target.value)}
                placeholder="Ex: Produits de base"
              />
            </label>

            <label className="form-label">
              Nom Arabe
              <input
                className="form-input"
                value={nameAr}
                onChange={(e) => setNameAr(e.target.value)}
                placeholder="مثال: المواد الأساسية"
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
              disabled={!(nameAr.trim() || nameFr.trim()) || (mode !== 'edit' && !file)}
            >
              {mode === 'edit' ? 'Enregistrer' : 'Ajouter'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default function Categories() {
  const navigate = useNavigate()
  const { familleId } = useParams()
  const [open, setOpen] = useState(false)
  const [editOpen, setEditOpen] = useState(false)
  const [editing, setEditing] = useState(null)

  const [categories, setCategories] = useState([])
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

  const load = useCallback(async () => {
    setError('')
    setLoading(true)

    try {
      const [categoriesRes, famillesRes] = await Promise.all([
        apiFetch(familleId ? `/api/categories?famille_id=${familleId}&per_page=1000` : '/api/categories?per_page=1000'),
        apiFetch('/api/familles')
      ])

      const categoriesItems = Array.isArray(categoriesRes?.data) ? categoriesRes.data : categoriesRes?.data?.data || []
      const famillesItems = Array.isArray(famillesRes) ? famillesRes : famillesRes?.data || []

      const countMap = getMap(COUNT_KEY)
      const nextCount = { ...countMap }

      for (const c of categoriesItems) {
        if (nextCount[c.id] == null) {
          nextCount[c.id] = Math.floor(Math.random() * 70) + 5
        }
      }

      setMap(COUNT_KEY, nextCount)

      setCategories(
        categoriesItems.map((c) => ({
          id: c.id,
          nom: c.nom,
          name_ar: c.name_ar,
          name_fr: c.name_fr,
          image: c.image || null,
          famille_id: c.famille_id,
          produits: nextCount[c.id],
        }))
      )

      setFamilles(famillesItems)
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setLoading(false)
    }
  }, [familleId])

  useEffect(() => {
    load()
  }, [load])

  useEffect(() => {
    return () => {
      if (errTimerRef.current) window.clearTimeout(errTimerRef.current)
    }
  }, [])

  const totals = useMemo(() => {
    const totalCategories = categories.length
    const totalProduits = categories.reduce((sum, c) => sum + c.produits, 0)
    return { totalCategories, totalProduits }
  }, [categories])

  async function addCategory(values) {
    try {
      const form = new FormData()
      form.append('nom', values.nom)
      form.append('name_ar', values.name_ar)
      form.append('name_fr', values.name_fr)
      form.append('description', '')
      form.append('famille_id', values.famille_id || '')
      form.append('image', values.file)

      await apiFetch('/api/categories', {
        method: 'POST',
        body: form,
      })

      setOpen(false)
      await load()
    } catch (e) {
      showTempError(e?.message || 'Erreur')
    }
  }

  async function updateCategory(values) {
    if (!editing?.id) return

    try {
      const form = new FormData()
      form.append('_method', 'PUT')
      form.append('nom', values.nom)
      form.append('name_ar', values.name_ar)
      form.append('name_fr', values.name_fr)
      form.append('description', '')
      form.append('famille_id', values.famille_id || '')

      if (values.file) {
        form.append('image', values.file)
      }

      await apiFetch(`/api/categories/${editing.id}`, {
        method: 'POST',
        body: form,
      })

      setEditOpen(false)
      setEditing(null)
      await load()
    } catch (e) {
      showTempError(e?.message || 'Erreur')
    }
  }

  function askDelete(cat) {
    setToDelete(cat)
    setConfirmOpen(true)
  }

  async function confirmDelete() {
    if (!toDelete) return
    setConfirmOpen(false)
    try {
      await apiFetch(`/api/categories/${toDelete.id}`, { method: 'DELETE' })
      setToDelete(null)
      await load()
    } catch (e) {
      showTempError(e?.message || 'Erreur')
    }
  }

  const currentFamille = familles.find(f => f.id == familleId)

  return (
    <section className="content">
      <div className="page-head">
        <div>
          <div className="page-title page-title-xl">
            {familleId ? `Catégories de ${currentFamille?.nom_fr || currentFamille?.nom_ar || 'Famille'}` : 'Catégories'}
          </div>
          <div className="page-subtitle">
            {familleId ? 'Gérer les catégories de cette famille' : 'Gérer les catégories de produits'}
          </div>
        </div>

        <button className="primary primary-pill" type="button" onClick={() => setOpen(true)}>
          <Plus size={16} />
          Ajouter Catégorie
        </button>
      </div>

      <Alert type="error" message={error} />

      <div className="cat-grid">
        {loading ? <div className="products-empty">Chargement…</div> : null}

        {!loading &&
          categories.map((c) => (
            <div
              key={c.id}
              className="cat-card"
              onClick={() => navigate(`/admin/categories/${c.id}`)}
              role="button"
              tabIndex={0}
            >
              <div className="cat-top">
                <div className="cat-ico">
                  {c.image ? (
                    <img className="cat-img" src={c.image} alt={c.nom} />
                  ) : (
                    <div className="cat-img-fallback">{(c.nom || '?')[0]}</div>
                  )}
                </div>

                <div>
                  <div className="cat-name">{c.nom}</div>

                  {(c.name_ar || c.name_fr) && (
                    <div style={{ fontSize: '11px', color: '#64748b' }}>
                      {c.name_fr} {c.name_ar && `| ${c.name_ar}`}
                    </div>
                  )}

                  <div className="cat-count">{c.produits} produits</div>
                </div>
              </div>

              <div className="cat-actions" onClick={(e) => e.stopPropagation()}>
                <button
                  className="cat-btn"
                  type="button"
                  onClick={() => {
                    setEditing(c)
                    setEditOpen(true)
                  }}
                >
                  <Pencil size={16} />
                  Modifier
                </button>

                <button
                  className="cat-icon-btn"
                  type="button"
                  onClick={() => navigate(`/admin/categories/${c.id}`)}
                  aria-label="Catégories"
                >
                  <FolderTree size={16} />
                </button>

                <button
                  className="cat-icon-btn cat-icon-btn-danger"
                  type="button"
                  onClick={() => askDelete(c)}
                  aria-label="Supprimer"
                >
                  <Trash2 size={16} />
                </button>
              </div>
            </div>
          ))}
      </div>

      <div className="cat-stats">
        <div>
          <div className="cat-stats-label">Total Familles de Catégories</div>
          <div className="cat-stats-value">{totals.totalCategories}</div>
        </div>

        <div className="cat-stats-right">
          <div className="cat-stats-label">Total Produits</div>
          <div className="cat-stats-value">{totals.totalProduits}</div>
        </div>
      </div>

      <CategoryModal
        key={`create-${open ? '1' : '0'}`}
        open={open}
        mode="create"
        familles={familles}
        onClose={() => setOpen(false)}
        onSubmit={addCategory}
      />

      <CategoryModal
        key={`edit-${editOpen ? editing?.id || 'x' : '0'}`}
        open={editOpen}
        mode="edit"
        initialValues={editing}
        familles={familles}
        onClose={() => {
          setEditOpen(false)
          setEditing(null)
        }}
        onSubmit={updateCategory}
      />

      <ConfirmDialog
        open={confirmOpen}
        title="Supprimer la catégorie"
        message={`Voulez-vous vraiment supprimer la catégorie « ${toDelete?.nom} » ? Cette action est irréversible.`}
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