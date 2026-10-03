import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { LayoutGrid, Plus, Search } from 'lucide-react'
import { apiFetch } from '../../lib/api'
import ConfirmDialog from '../../components/ConfirmDialog'
import { toast } from '../../lib/toast'
import { EntityCard, EntityModal, Empty, Hero, Skeletons } from '../../components/catalogue/CatalogueUI'
import { fmtInt, listOf } from '../../components/catalogue/format'

export default function SousCategories() {
  const navigate = useNavigate()
  const { categorieId } = useParams()
  const [sous, setSous] = useState([])
  const [categories, setCategories] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [q, setQ] = useState('')
  const [modal, setModal] = useState(null)
  const [toDelete, setToDelete] = useState(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const [sc, cats] = await Promise.all([
        apiFetch(`/api/sous_categories?categorie_id=${categorieId || ''}&per_page=1000`),
        apiFetch('/api/categories?per_page=1000'),
      ])
      setSous(listOf(sc))
      setCategories(listOf(cats))
    } catch (e) {
      setError(e?.message || 'Chargement impossible')
    } finally {
      setLoading(false)
    }
  }, [categorieId])

  useEffect(() => {
    load()
  }, [load])

  const categorie = categories.find((c) => String(c.id) === String(categorieId)) || null
  const famille = categorie?.famille || null
  const siblings = categorie ? categories.filter((c) => c.famille_id === categorie.famille_id) : []

  const shown = useMemo(() => {
    const s = q.trim().toLowerCase()
    return sous.filter((x) => !s || `${x.nom || ''} ${x.name_fr || ''} ${x.name_ar || ''}`.toLowerCase().includes(s))
  }, [sous, q])

  const totalArticles = shown.reduce((n, x) => n + Number(x.articles_count || 0), 0)

  async function save(values) {
    const form = new FormData()
    form.append('categorie_id', values.parent_id)
    form.append('nom', values.name_fr || values.name_ar)
    form.append('name_fr', values.name_fr)
    form.append('name_ar', values.name_ar)
    form.append('description', '')
    if (values.file) form.append('image', values.file)
    try {
      if (modal?.mode === 'edit') {
        form.append('_method', 'PUT')
        await apiFetch(`/api/sous_categories/${modal.item.id}`, { method: 'POST', body: form })
        toast({ type: 'success', message: 'Sous-catégorie modifiée.' })
      } else {
        await apiFetch('/api/sous_categories', { method: 'POST', body: form })
        toast({ type: 'success', message: 'Sous-catégorie ajoutée.' })
      }
      setModal(null)
      await load()
    } catch (e) {
      toast({ type: 'error', message: e?.message || 'Erreur' })
    }
  }

  async function remove() {
    const x = toDelete
    setToDelete(null)
    try {
      await apiFetch(`/api/sous_categories/${x.id}`, { method: 'DELETE' })
      toast({ type: 'success', message: 'Sous-catégorie supprimée.' })
      await load()
    } catch (e) {
      toast({ type: 'error', message: e?.message || 'Suppression impossible' })
    }
  }

  const modalInitial = modal?.item
    ? { name_fr: modal.item.name_fr || modal.item.nom, name_ar: modal.item.name_ar, parent_id: modal.item.categorie_id, image: modal.item.image }
    : { parent_id: categorieId }

  return (
    <section className="cx">
      <Hero
        crumbs={[
          { label: 'Catalogue', to: '/admin/familles' },
          ...(famille ? [{ label: famille.nom_fr, to: `/admin/familles/${famille.id}/categories` }] : []),
          { label: categorie ? categorie.name_fr || categorie.nom : 'Catégorie' },
        ]}
        image={categorie?.image}
        title={categorie ? categorie.name_fr || categorie.nom : 'Sous-catégories'}
        titleAr={categorie?.name_ar}
        subtitle="Ouvrez une sous-catégorie pour voir, tarifer et modifier ses produits."
        stats={[
          { label: 'Sous-catégories', value: fmtInt(shown.length) },
          { label: 'Produits', value: fmtInt(totalArticles) },
        ]}
        actions={
          <>
            <button
              className="cx-btn cx-btn-ghost-light"
              type="button"
              onClick={() => navigate(`/admin/produits?categorie=${categorieId}`)}
            >
              <LayoutGrid size={16} /> Tous ses produits
            </button>
            <button className="cx-btn cx-btn-primary" type="button" onClick={() => setModal({ mode: 'create' })}>
              <Plus size={16} /> Nouvelle sous-catégorie
            </button>
          </>
        }
      />

      {error ? <div className="cx-alert">{error}</div> : null}

      <div className="cx-toolbar">
        <label className="cx-search">
          <Search size={18} color="#94a3b8" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Rechercher une sous-catégorie…" />
        </label>
      </div>

      {siblings.length > 1 ? (
        <div className="cx-chips">
          {siblings.map((c) => (
            <button
              key={c.id}
              className={`cx-chip ${String(c.id) === String(categorieId) ? 'on' : ''}`}
              type="button"
              onClick={() => navigate(`/admin/categories/${c.id}`)}
            >
              {c.image ? <img className="cx-chip-img" src={c.image} alt="" /> : null}
              {c.name_fr || c.nom}
              <span className="cx-chip-count">{fmtInt(c.sous_categories_count)}</span>
            </button>
          ))}
        </div>
      ) : null}

      <div className="cx-grid">
        {loading ? <Skeletons count={8} height={260} /> : null}
        {!loading && shown.length === 0 ? (
          <Empty title={q ? 'Aucune sous-catégorie ne correspond' : 'Aucune sous-catégorie'}>
            {q ? 'Essayez un autre mot.' : 'Ajoutez une sous-catégorie pour ranger les produits.'}
          </Empty>
        ) : null}
        {!loading &&
          shown.map((x) => (
            <EntityCard
              key={x.id}
              image={x.image}
              title={x.name_fr || x.nom}
              titleAr={x.name_ar}
              badge={`${fmtInt(x.articles_count)} produits`}
              pills={[{ label: 'Voir les produits', tone: 'red' }]}
              onOpen={() => navigate(`/admin/produits?sous_categorie=${x.id}`)}
              onEdit={() => setModal({ mode: 'edit', item: x })}
              onDelete={() => setToDelete(x)}
            />
          ))}
      </div>

      <EntityModal
        open={!!modal}
        title={modal?.mode === 'edit' ? 'Modifier la sous-catégorie' : 'Nouvelle sous-catégorie'}
        initial={modalInitial}
        parentLabel="Catégorie"
        parents={categories}
        parentKey="name_fr"
        requireImage
        onClose={() => setModal(null)}
        onSubmit={save}
      />

      <ConfirmDialog
        open={!!toDelete}
        title="Supprimer la sous-catégorie"
        message={`Supprimer « ${toDelete?.name_fr || toDelete?.nom} » ?`}
        confirmLabel="Supprimer"
        onConfirm={remove}
        onCancel={() => setToDelete(null)}
      />
    </section>
  )
}
