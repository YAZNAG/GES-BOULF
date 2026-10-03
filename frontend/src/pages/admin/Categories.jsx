import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { LayoutGrid, Plus, Search } from 'lucide-react'
import { apiFetch } from '../../lib/api'
import ConfirmDialog from '../../components/ConfirmDialog'
import { toast } from '../../lib/toast'
import { EntityCard, EntityModal, Empty, Hero, Skeletons } from '../../components/catalogue/CatalogueUI'
import { fmtInt, listOf } from '../../components/catalogue/format'

export default function Categories() {
  const navigate = useNavigate()
  const { familleId } = useParams()
  const [categories, setCategories] = useState([])
  const [familles, setFamilles] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [q, setQ] = useState('')
  const [modal, setModal] = useState(null)
  const [toDelete, setToDelete] = useState(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const [cats, fams] = await Promise.all([
        apiFetch('/api/categories?per_page=1000'),
        apiFetch('/api/familles?per_page=200'),
      ])
      setCategories(listOf(cats))
      setFamilles(listOf(fams))
    } catch (e) {
      setError(e?.message || 'Chargement impossible')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  const famille = familles.find((f) => String(f.id) === String(familleId)) || null

  const shown = useMemo(() => {
    const s = q.trim().toLowerCase()
    return categories.filter(
      (c) =>
        (!familleId || String(c.famille_id) === String(familleId)) &&
        (!s || `${c.nom || ''} ${c.name_fr || ''} ${c.name_ar || ''}`.toLowerCase().includes(s))
    )
  }, [categories, familleId, q])

  const sum = (key) => shown.reduce((n, c) => n + Number(c[key] || 0), 0)

  async function save(values) {
    const form = new FormData()
    form.append('nom', values.name_fr || values.name_ar)
    form.append('name_fr', values.name_fr)
    form.append('name_ar', values.name_ar)
    form.append('description', '')
    form.append('famille_id', values.parent_id || '')
    if (values.file) form.append('image', values.file)
    try {
      if (modal?.mode === 'edit') {
        form.append('_method', 'PUT')
        await apiFetch(`/api/categories/${modal.item.id}`, { method: 'POST', body: form })
        toast({ type: 'success', message: 'Catégorie modifiée.' })
      } else {
        await apiFetch('/api/categories', { method: 'POST', body: form })
        toast({ type: 'success', message: 'Catégorie ajoutée.' })
      }
      setModal(null)
      await load()
    } catch (e) {
      toast({ type: 'error', message: e?.message || 'Erreur' })
    }
  }

  async function remove() {
    const c = toDelete
    setToDelete(null)
    try {
      await apiFetch(`/api/categories/${c.id}`, { method: 'DELETE' })
      toast({ type: 'success', message: 'Catégorie supprimée.' })
      await load()
    } catch (e) {
      toast({ type: 'error', message: e?.message || 'Suppression impossible' })
    }
  }

  const goFamille = (id) => navigate(id ? `/admin/familles/${id}/categories` : '/admin/categories')

  const modalInitial = modal?.item
    ? { name_fr: modal.item.name_fr || modal.item.nom, name_ar: modal.item.name_ar, parent_id: modal.item.famille_id, image: modal.item.image }
    : familleId
      ? { parent_id: familleId }
      : null

  return (
    <section className="cx">
      <Hero
        crumbs={[{ label: 'Catalogue', to: '/admin/familles' }, { label: famille ? famille.nom_fr : 'Catégories' }]}
        image={famille?.image}
        title={famille ? famille.nom_fr : 'Toutes les catégories'}
        titleAr={famille ? famille.nom_ar : 'جميع الفئات'}
        subtitle="Choisissez une catégorie pour parcourir ses sous-catégories et ses produits."
        stats={[
          { label: 'Catégories', value: fmtInt(shown.length) },
          { label: 'Sous-catégories', value: fmtInt(sum('sous_categories_count')) },
          { label: 'Produits', value: fmtInt(sum('articles_count')) },
        ]}
        actions={
          <>
            <button
              className="cx-btn cx-btn-ghost-light"
              type="button"
              onClick={() => navigate(famille ? `/admin/produits?famille=${famille.id}` : '/admin/produits')}
            >
              <LayoutGrid size={16} /> Voir les produits
            </button>
            <button className="cx-btn cx-btn-primary" type="button" onClick={() => setModal({ mode: 'create' })}>
              <Plus size={16} /> Nouvelle catégorie
            </button>
          </>
        }
      />

      {error ? <div className="cx-alert">{error}</div> : null}

      <div className="cx-toolbar">
        <label className="cx-search">
          <Search size={18} color="#94a3b8" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Rechercher une catégorie…" />
        </label>
      </div>

      {familles.length > 1 ? (
        <div className="cx-chips">
          <button className={`cx-chip ${!familleId ? 'on' : ''}`} type="button" onClick={() => goFamille(null)}>
            Toutes <span className="cx-chip-count">{fmtInt(categories.length)}</span>
          </button>
          {familles.map((f) => (
            <button
              key={f.id}
              className={`cx-chip ${String(f.id) === String(familleId) ? 'on' : ''}`}
              type="button"
              onClick={() => goFamille(f.id)}
            >
              {f.image ? <img className="cx-chip-img" src={f.image} alt="" /> : null}
              {f.nom_fr}
              <span className="cx-chip-count">{fmtInt(f.categories_count)}</span>
            </button>
          ))}
        </div>
      ) : null}

      <div className="cx-grid">
        {loading ? <Skeletons count={8} height={260} /> : null}
        {!loading && shown.length === 0 ? (
          <Empty title={q ? 'Aucune catégorie ne correspond' : 'Aucune catégorie ici'}>
            {q ? 'Essayez un autre mot.' : 'Ajoutez une catégorie avec le bouton « Nouvelle catégorie ».'}
          </Empty>
        ) : null}
        {!loading &&
          shown.map((c) => (
            <EntityCard
              key={c.id}
              image={c.image}
              title={c.name_fr || c.nom}
              titleAr={c.name_ar}
              badge={`${fmtInt(c.articles_count)} produits`}
              pills={[
                { label: `${fmtInt(c.sous_categories_count)} sous-catégories` },
                ...(!familleId && c.famille ? [{ label: c.famille.nom_fr, tone: 'gray' }] : []),
              ]}
              onOpen={() => navigate(`/admin/categories/${c.id}`)}
              onEdit={() => setModal({ mode: 'edit', item: c })}
              onDelete={() => setToDelete(c)}
            />
          ))}
      </div>

      <EntityModal
        open={!!modal}
        title={modal?.mode === 'edit' ? 'Modifier la catégorie' : 'Nouvelle catégorie'}
        initial={modalInitial}
        parentLabel="Famille"
        parents={familles}
        parentKey="nom_fr"
        requireImage
        onClose={() => setModal(null)}
        onSubmit={save}
      />

      <ConfirmDialog
        open={!!toDelete}
        title="Supprimer la catégorie"
        message={`Supprimer « ${toDelete?.name_fr || toDelete?.nom} » et ses sous-catégories ?`}
        confirmLabel="Supprimer"
        onConfirm={remove}
        onCancel={() => setToDelete(null)}
      />
    </section>
  )
}
