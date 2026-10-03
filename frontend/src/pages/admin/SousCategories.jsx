import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { FolderTree, Pencil, Plus, Trash2, X } from 'lucide-react'
import { apiFetch } from '../../lib/api'
import Alert from '../../components/Alert'
import ConfirmDialog from '../../components/ConfirmDialog'
import '../../styles/categories.css'

const COUNT_KEY = 'gs_sous_categorie_count'

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

function SousCategorieModal({ open, mode = 'create', initialValues, categories, onClose, onSubmit }) {
  const [categorieId, setCategorieId] = useState('')
  const [nameAr, setNameAr] = useState('')
  const [nameFr, setNameFr] = useState('')
  const [file, setFile] = useState(null)
  const [preview, setPreview] = useState(null)

  useEffect(() => {
    if (open) {
      setCategorieId(initialValues?.categorie_id ?? '')
      setNameAr(initialValues?.name_ar ?? '')
      setNameFr(initialValues?.name_fr ?? '')
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
    if (!categorieId) return

    const nom = nameFr.trim() || nameAr.trim() || 'Sans nom'

    onSubmit({
      categorie_id: categorieId,
      name_ar: nameAr.trim(),
      name_fr: nameFr.trim(),
      nom,
      file,
    })
  }

  return (
    <div className="modal-overlay" onMouseDown={onClose}>
      <div className="modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-title">
            {mode === 'edit'
              ? 'Modifier une Catégorie'
              : 'Ajouter une Catégorie'}
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
              value={categorieId}
              onChange={(e) => setCategorieId(e.target.value)}
            >
              <option value="">Sélectionner une Famille</option>
              {categories.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.nom}
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
              <img className="cat-img" src={preview} alt="Aperçu catégorie" />
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
              disabled={!categorieId || !(nameAr.trim() || nameFr.trim()) || (mode !== 'edit' && !file)}
            >
              {mode === 'edit' ? 'Enregistrer' : 'Ajouter'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default function SousCategories() {
  const navigate = useNavigate()
  const { categorieId } = useParams()
  const [open, setOpen] = useState(false)
  const [editOpen, setEditOpen] = useState(false)
  const [editing, setEditing] = useState(null)

  const [sousCategories, setSousCategories] = useState([])
  const [categories, setCategories] = useState([])
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
      const [sousRes, catRes] = await Promise.all([
        apiFetch(`/api/sous_categories?categorie_id=${categorieId || ''}&per_page=1000`),
        apiFetch('/api/categories?per_page=1000')
      ])

      const sousItems = Array.isArray(sousRes?.data) ? sousRes.data : sousRes?.data?.data || []
      const catItems = Array.isArray(catRes?.data) ? catRes.data : catRes?.data?.data || []

      const countMap = getMap(COUNT_KEY)
      const nextCount = { ...countMap }

      for (const c of sousItems) {
        if (nextCount[c.id] == null) {
          nextCount[c.id] = Math.floor(Math.random() * 70) + 5
        }
      }

      setMap(COUNT_KEY, nextCount)

      setSousCategories(
        sousItems.map((c) => ({
          id: c.id,
          categorie_id: c.categorie_id,
          nom: c.nom,
          name_ar: c.name_ar,
          name_fr: c.name_fr,
          image: c.image || null,
          produits: nextCount[c.id],
        }))
      )

      setCategories(catItems)
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
  }, [categorieId])

  useEffect(() => {
    return () => {
      if (errTimerRef.current) window.clearTimeout(errTimerRef.current)
    }
  }, [])

  const totals = useMemo(() => {
    const totalSousCategories = sousCategories.length
    const totalProduits = sousCategories.reduce((sum, c) => sum + c.produits, 0)
    return { totalSousCategories, totalProduits }
  }, [sousCategories])

  async function addSousCategorie(values) {
    try {
      const form = new FormData()
      form.append('categorie_id', values.categorie_id)
      form.append('nom', values.nom)
      form.append('name_ar', values.name_ar)
      form.append('name_fr', values.name_fr)
      form.append('description', '')
      form.append('image', values.file)

      await apiFetch('/api/sous_categories', {
        method: 'POST',
        body: form,
      })

      setOpen(false)
      await load()
    } catch (e) {
      showTempError(e?.message || 'Erreur')
    }
  }

  async function updateSousCategorie(values) {
    if (!editing?.id) return

    try {
      const form = new FormData()
      form.append('_method', 'PUT')
      form.append('categorie_id', values.categorie_id)
      form.append('nom', values.nom)
      form.append('name_ar', values.name_ar)
      form.append('name_fr', values.name_fr)
      form.append('description', '')

      if (values.file) {
        form.append('image', values.file)
      }

      await apiFetch(`/api/sous_categories/${editing.id}`, {
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
      await apiFetch(`/api/sous_categories/${toDelete.id}`, { method: 'DELETE' })
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
          <div className="page-title page-title-xl">Catégories</div>
          <div className="page-subtitle">Organiser les produits par catégories</div>
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
          sousCategories.map((c) => (
            <div
              key={c.id}
              className="cat-card"
              onClick={() => navigate(`/admin/sous_categories/${c.id}/articles`)}
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
                  onClick={() => navigate(`/admin/sous_categories/${c.id}/articles`)}
                  aria-label="Produits"
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
          <div className="cat-stats-label">Total Catégories</div>
          <div className="cat-stats-value">{totals.totalSousCategories}</div>
        </div>

        <div className="cat-stats-right">
          <div className="cat-stats-label">Total Produits</div>
          <div className="cat-stats-value">{totals.totalProduits}</div>
        </div>
      </div>

      <SousCategorieModal
        key={`create-${open ? '1' : '0'}`}
        open={open}
        mode="create"
        categories={categories}
        onClose={() => setOpen(false)}
        onSubmit={addSousCategorie}
      />

      <SousCategorieModal
        key={`edit-${editOpen ? editing?.id || 'x' : '0'}`}
        open={editOpen}
        mode="edit"
        initialValues={editing}
        categories={categories}
        onClose={() => {
          setEditOpen(false)
          setEditing(null)
        }}
        onSubmit={updateSousCategorie}
      />

      <ConfirmDialog
        open={confirmOpen}
        title="Supprimer la sous-catégorie"
        message={`Voulez-vous vraiment supprimer « ${toDelete?.nom} » ? Cette action est irréversible.`}
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