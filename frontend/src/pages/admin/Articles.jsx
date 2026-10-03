import { useEffect, useRef, useState } from 'react'
import { useParams } from 'react-router-dom'
import { Pencil, Plus, Trash2, X } from 'lucide-react'
import { apiFetch } from '../../lib/api'
import Alert from '../../components/Alert'
import ConfirmDialog from '../../components/ConfirmDialog'
import '../../styles/categories.css'

function ArticleModal({ open, mode = 'create', initialValues, sousCategories, marques, unites, onClose, onSubmit }) {
  const [sousCategorieId, setSousCategorieId] = useState('')
  const [marqueId, setMarqueId] = useState('')
  const [codeArticle, setCodeArticle] = useState('')
  const [nameAr, setNameAr] = useState('')
  const [nameFr, setNameFr] = useState('')
  const [description, setDescription] = useState('')
  const [unite, setUnite] = useState('')
  const [file, setFile] = useState(null)
  const [preview, setPreview] = useState(null)
  const [prixAchat, setPrixAchat] = useState('')
  const [prixVente, setPrixVente] = useState('')
  const [prixGros, setPrixGros] = useState('')
  const [stockInitial, setStockInitial] = useState('')
  const [seuilMin, setSeuilMin] = useState('')

  useEffect(() => {
    if (open) {
      setSousCategorieId(initialValues?.sous_categorie_id ?? '')
      setMarqueId(initialValues?.marque_id ?? '')
      setCodeArticle(initialValues?.code_article ?? '')
      setNameAr(initialValues?.name_ar ?? '')
      setNameFr(initialValues?.name_fr ?? '')
      setDescription(initialValues?.description ?? '')
      setUnite(initialValues?.unite ?? '')
      setFile(null)
      setPreview(initialValues?.image ?? null)
      setPrixAchat(initialValues?.prix?.prix_achat ?? '')
      setPrixVente(initialValues?.prix?.prix_vente ?? '')
      setPrixGros(initialValues?.prix?.prix_gros ?? '')
      setStockInitial(initialValues?.stock?.quantite ?? '')
      setSeuilMin(initialValues?.stock?.seuil_min ?? '')
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
    if (!codeArticle.trim()) return
    if (!sousCategorieId) return
    if (mode !== 'edit' && !file) return

    onSubmit({
      sous_categorie_id: sousCategorieId,
      marque_id: marqueId || null,
      code_article: codeArticle.trim(),
      name_ar: nameAr.trim(),
      name_fr: nameFr.trim(),
      nom: nameFr.trim() || nameAr.trim() || 'Sans nom',
      description: description.trim(),
      unite: unite.trim(),
      file,
      prix_achat: prixAchat ? parseFloat(prixAchat) : null,
      prix_vente: prixVente ? parseFloat(prixVente) : null,
      prix_gros: prixGros ? parseFloat(prixGros) : null,
      stock_initial: stockInitial ? parseFloat(stockInitial) : null,
      seuil_min: seuilMin ? parseFloat(seuilMin) : null,
    })
  }

  return (
    <div className="modal-overlay" onMouseDown={onClose}>
      <div className="modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-title">
            {mode === 'edit' ? 'Modifier un Produit' : 'Ajouter un Produit'}
          </div>
          <button className="modal-x" type="button" onClick={onClose} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>

        <form className="modal-body" onSubmit={submit}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <label className="form-label">
              Sous-Catégorie
              <select
                className="form-input"
                value={sousCategorieId}
                onChange={(e) => setSousCategorieId(e.target.value)}
              >
                <option value="">Sélectionner</option>
                {sousCategories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.nom}
                  </option>
                ))}
              </select>
            </label>

            <label className="form-label">
              Marque
              <select
                className="form-input"
                value={marqueId}
                onChange={(e) => setMarqueId(e.target.value)}
              >
                <option value="">Aucune</option>
                {marques.map((m) => (
                  <option key={m.id} value={m.id}>
                    {m.nom}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <label className="form-label">
            Code Article
            <input
              className="form-input"
              value={codeArticle}
              onChange={(e) => setCodeArticle(e.target.value)}
              placeholder="Ex: ART001"
              required
            />
          </label>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <label className="form-label">
              Nom Français
              <input
                className="form-input"
                value={nameFr}
                onChange={(e) => setNameFr(e.target.value)}
                placeholder="Ex: Produit A"
              />
            </label>

            <label className="form-label">
              Nom Arabe
              <input
                className="form-input"
                value={nameAr}
                onChange={(e) => setNameAr(e.target.value)}
                placeholder="مثال: المنتج أ"
                dir="rtl"
              />
            </label>
          </div>

          <label className="form-label">
            Description
            <textarea
              className="form-input"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={2}
            />
          </label>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '12px' }}>
            <label className="form-label">
              Unité
              <select
                className="form-input"
                value={unite}
                onChange={(e) => setUnite(e.target.value)}
              >
                <option value="">Aucune</option>
                {unites.map((u) => (
                  <option key={u.id} value={u.nom}>
                    {u.nom}
                  </option>
                ))}
              </select>
            </label>

            <label className="form-label">
              Prix Achat
              <input
                className="form-input"
                type="number"
                step="0.01"
                value={prixAchat}
                onChange={(e) => setPrixAchat(e.target.value)}
              />
            </label>

            <label className="form-label">
              Prix Vente
              <input
                className="form-input"
                type="number"
                step="0.01"
                value={prixVente}
                onChange={(e) => setPrixVente(e.target.value)}
              />
            </label>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '12px' }}>
            <label className="form-label">
              Prix Gros
              <input
                className="form-input"
                type="number"
                step="0.01"
                value={prixGros}
                onChange={(e) => setPrixGros(e.target.value)}
              />
            </label>

            <label className="form-label">
              Stock Initial
              <input
                className="form-input"
                type="number"
                step="0.01"
                value={stockInitial}
                onChange={(e) => setStockInitial(e.target.value)}
              />
            </label>

            <label className="form-label">
              Seuil Min
              <input
                className="form-input"
                type="number"
                step="0.01"
                value={seuilMin}
                onChange={(e) => setSeuilMin(e.target.value)}
              />
            </label>
          </div>

          {preview ? (
            <div className="cat-ico" style={{ marginBottom: '12px' }}>
              <img className="cat-img" src={preview} alt="Aperçu produit" />
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
              disabled={!sousCategorieId || !codeArticle.trim() || !(nameAr.trim() || nameFr.trim()) || (mode !== 'edit' && !file)}
            >
              {mode === 'edit' ? 'Enregistrer' : 'Ajouter'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default function Articles() {
  const { sousCategorieId } = useParams()
  const [open, setOpen] = useState(false)
  const [editOpen, setEditOpen] = useState(false)
  const [editing, setEditing] = useState(null)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [toDelete, setToDelete] = useState(null)

  const [articles, setArticles] = useState([])
  const [sousCategories, setSousCategories] = useState([])
  const [marques, setMarques] = useState([])
  const [unites, setUnites] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
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
      const [artRes, sousRes, marRes, uniRes] = await Promise.all([
        apiFetch(`/api/articles?sous_categorie_id=${sousCategorieId || ''}&per_page=1000`),
        apiFetch('/api/sous_categories?per_page=1000'),
        apiFetch('/api/marques?per_page=1000'),
        apiFetch('/api/unites?per_page=1000'),
      ])

      setArticles(Array.isArray(artRes?.data) ? artRes.data : artRes?.data?.data || [])
      setSousCategories(Array.isArray(sousRes?.data) ? sousRes.data : sousRes?.data?.data || [])
      setMarques(Array.isArray(marRes?.data) ? marRes.data : marRes?.data?.data || [])
      setUnites(Array.isArray(uniRes?.data) ? uniRes.data : uniRes?.data?.data || [])
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
  }, [sousCategorieId])

  useEffect(() => {
    return () => {
      if (errTimerRef.current) window.clearTimeout(errTimerRef.current)
    }
  }, [])

  async function addArticle(values) {
    try {
      const form = new FormData()
      form.append('sous_categorie_id', values.sous_categorie_id)
      if (values.marque_id) form.append('marque_id', values.marque_id)
      form.append('code_article', values.code_article)
      form.append('nom', values.nom)
      form.append('name_ar', values.name_ar)
      form.append('name_fr', values.name_fr)
      form.append('description', values.description)
      form.append('unite', values.unite)
      form.append('image', values.file)
      if (values.prix_achat !== null) form.append('prix_achat', values.prix_achat)
      if (values.prix_vente !== null) form.append('prix_vente', values.prix_vente)
      if (values.prix_gros !== null) form.append('prix_gros', values.prix_gros)
      if (values.stock_initial !== null) form.append('stock_initial', values.stock_initial)
      if (values.seuil_min !== null) form.append('seuil_min', values.seuil_min)

      await apiFetch('/api/articles', { method: 'POST', body: form })
      setOpen(false)
      await load()
    } catch (e) {
      showTempError(e?.message || 'Erreur')
    }
  }

  async function updateArticle(values) {
    if (!editing?.id) return
    try {
      const form = new FormData()
      form.append('_method', 'PUT')
      form.append('sous_categorie_id', values.sous_categorie_id)
      if (values.marque_id) form.append('marque_id', values.marque_id)
      form.append('code_article', values.code_article)
      form.append('nom', values.nom)
      form.append('name_ar', values.name_ar)
      form.append('name_fr', values.name_fr)
      form.append('description', values.description)
      form.append('unite', values.unite)
      if (values.file) form.append('image', values.file)

      await apiFetch(`/api/articles/${editing.id}`, { method: 'POST', body: form })
      setEditOpen(false)
      setEditing(null)
      await load()
    } catch (e) {
      showTempError(e?.message || 'Erreur')
    }
  }

  function askDelete(art) {
    setToDelete(art)
    setConfirmOpen(true)
  }

  async function confirmDelete() {
    if (!toDelete) return
    setConfirmOpen(false)
    try {
      await apiFetch(`/api/articles/${toDelete.id}`, { method: 'DELETE' })
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
          <div className="page-title page-title-xl">Produits</div>
          <div className="page-subtitle">Gérer les produits</div>
        </div>
        <button className="primary primary-pill" type="button" onClick={() => setOpen(true)}>
          <Plus size={16} />
          Ajouter Produit
        </button>
      </div>

      <Alert type="error" message={error} />

      <div className="cat-grid">
        {loading ? <div className="products-empty">Chargement…</div> : null}

        {!loading && articles.map((a) => (
          <div key={a.id} className="cat-card">
            <div className="cat-top">
              <div className="cat-ico">
                {a.image ? (
                  <img className="cat-img" src={a.image} alt={a.nom} />
                ) : (
                  <div className="cat-img-fallback">{(a.nom || '?')[0]}</div>
                )}
              </div>
              <div>
                <div className="cat-name">{a.nom}</div>
                <div className="cat-count">Code: {a.code_article}</div>
                {a.prix && <div className="cat-count">Prix: {a.prix.prix_vente}</div>}
                {a.stock && <div className="cat-count">Stock: {a.stock.quantite}</div>}
              </div>
            </div>

            <div className="cat-actions">
              <button
                className="cat-btn"
                type="button"
                onClick={() => {
                  setEditing(a)
                  setEditOpen(true)
                }}
              >
                <Pencil size={16} />
                Modifier
              </button>
              <button
                className="cat-icon-btn cat-icon-btn-danger"
                type="button"
                onClick={() => askDelete(a)}
                aria-label="Supprimer"
              >
                <Trash2 size={16} />
              </button>
            </div>
          </div>
        ))}
      </div>

      <ArticleModal
        key={`create-${open ? '1' : '0'}`}
        open={open}
        mode="create"
        sousCategories={sousCategories}
        marques={marques}
        unites={unites}
        onClose={() => setOpen(false)}
        onSubmit={addArticle}
      />

      <ArticleModal
        key={`edit-${editOpen ? editing?.id || 'x' : '0'}`}
        open={editOpen}
        mode="edit"
        initialValues={editing}
        sousCategories={sousCategories}
        marques={marques}
        unites={unites}
        onClose={() => {
          setEditOpen(false)
          setEditing(null)
        }}
        onSubmit={updateArticle}
      />

      <ConfirmDialog
        open={confirmOpen}
        title="Supprimer le produit"
        message={`Voulez-vous vraiment supprimer le produit « ${toDelete?.nom} » ? Cette action est irréversible.`}
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
