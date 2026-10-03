import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { LayoutGrid, Plus, Search } from 'lucide-react'
import { apiFetch } from '../../lib/api'
import ConfirmDialog from '../../components/ConfirmDialog'
import { toast } from '../../lib/toast'
import { EntityCard, EntityModal, Empty, Hero, Skeletons } from '../../components/catalogue/CatalogueUI'
import { fmtInt, listOf } from '../../components/catalogue/format'

export default function Familles() {
  const navigate = useNavigate()
  const [familles, setFamilles] = useState([])
  const [stats, setStats] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [q, setQ] = useState('')
  const [modal, setModal] = useState(null) // { mode, item }
  const [toDelete, setToDelete] = useState(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const [fam, art] = await Promise.all([
        apiFetch('/api/familles?per_page=200'),
        apiFetch('/api/articles?per_page=1&with_stats=1'),
      ])
      setFamilles(listOf(fam))
      setStats(art?.stats || null)
    } catch (e) {
      setError(e?.message || 'Chargement impossible')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  const shown = useMemo(() => {
    const s = q.trim().toLowerCase()
    return familles.filter((f) => !s || `${f.nom_fr || ''} ${f.nom_ar || ''}`.toLowerCase().includes(s))
  }, [familles, q])

  const totals = useMemo(
    () => ({
      categories: familles.reduce((n, f) => n + Number(f.categories_count || 0), 0),
      sous: familles.reduce((n, f) => n + Number(f.sous_categories_count || 0), 0),
    }),
    [familles]
  )

  async function save(values) {
    const form = new FormData()
    form.append('nom_fr', values.name_fr)
    form.append('nom_ar', values.name_ar)
    if (values.file) form.append('image', values.file)
    try {
      if (modal?.mode === 'edit') {
        form.append('_method', 'PUT')
        await apiFetch(`/api/familles/${modal.item.id}`, { method: 'POST', body: form })
        toast({ type: 'success', message: 'Famille modifiée.' })
      } else {
        await apiFetch('/api/familles', { method: 'POST', body: form })
        toast({ type: 'success', message: 'Famille ajoutée.' })
      }
      setModal(null)
      await load()
    } catch (e) {
      toast({ type: 'error', message: e?.message || 'Erreur' })
    }
  }

  async function remove() {
    const f = toDelete
    setToDelete(null)
    try {
      await apiFetch(`/api/familles/${f.id}`, { method: 'DELETE' })
      toast({ type: 'success', message: 'Famille supprimée.' })
      await load()
    } catch (e) {
      toast({ type: 'error', message: e?.message || 'Suppression impossible' })
    }
  }

  return (
    <section className="cx">
      <Hero
        crumbs={[{ label: 'Catalogue' }]}
        title="Familles de produits"
        titleAr="عائلات المنتجات"
        subtitle="Les grands univers du magasin. Ouvrez une famille pour voir ses catégories, sous-catégories et produits."
        stats={[
          { label: 'Familles', value: fmtInt(familles.length) },
          { label: 'Catégories', value: fmtInt(totals.categories) },
          { label: 'Sous-catégories', value: fmtInt(totals.sous) },
          { label: 'Produits', value: fmtInt(stats?.total) },
          ...(stats?.a_tarifer ? [{ label: 'Produits à tarifer', value: fmtInt(stats.a_tarifer), warn: true }] : []),
        ]}
        actions={
          <>
            <button className="cx-btn cx-btn-ghost-light" type="button" onClick={() => navigate('/admin/produits')}>
              <LayoutGrid size={16} /> Tous les produits
            </button>
            <button className="cx-btn cx-btn-primary" type="button" onClick={() => setModal({ mode: 'create' })}>
              <Plus size={16} /> Nouvelle famille
            </button>
          </>
        }
      />

      {error ? <div className="cx-alert">{error}</div> : null}

      <div className="cx-toolbar">
        <label className="cx-search">
          <Search size={18} color="#94a3b8" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Rechercher une famille…" />
        </label>
      </div>

      <div className="cx-grid cx-grid-lg">
        {loading ? <Skeletons count={4} height={280} /> : null}
        {!loading && shown.length === 0 ? (
          <Empty
            title={q ? 'Aucune famille ne correspond' : 'Aucune famille'}
            action={
              !q && (
                <button className="cx-btn cx-btn-primary" type="button" onClick={() => setModal({ mode: 'create' })}>
                  <Plus size={16} /> Créer une famille
                </button>
              )
            }
          >
            {q ? 'Essayez un autre mot.' : 'Créez votre premier univers (Alimentation, Hygiène, Entretien…).'}
          </Empty>
        ) : null}
        {!loading &&
          shown.map((f) => (
            <EntityCard
              key={f.id}
              image={f.image}
              title={f.nom_fr || f.nom_ar}
              titleAr={f.nom_fr ? f.nom_ar : null}
              badge={`${fmtInt(f.articles_count)} produits`}
              pills={[
                { label: `${fmtInt(f.categories_count)} catégories` },
                { label: `${fmtInt(f.sous_categories_count)} sous-catégories`, tone: 'gray' },
              ]}
              onOpen={() => navigate(`/admin/familles/${f.id}/categories`)}
              onEdit={() => setModal({ mode: 'edit', item: f })}
              onDelete={() => setToDelete(f)}
            />
          ))}
      </div>

      <EntityModal
        open={!!modal}
        title={modal?.mode === 'edit' ? 'Modifier la famille' : 'Nouvelle famille'}
        initial={modal?.item ? { name_fr: modal.item.nom_fr, name_ar: modal.item.nom_ar, image: modal.item.image } : null}
        onClose={() => setModal(null)}
        onSubmit={save}
      />

      <ConfirmDialog
        open={!!toDelete}
        title="Supprimer la famille"
        message={`Supprimer « ${toDelete?.nom_fr || toDelete?.nom_ar} » ? Ses catégories seront aussi supprimées.`}
        confirmLabel="Supprimer"
        onConfirm={remove}
        onCancel={() => setToDelete(null)}
      />
    </section>
  )
}
