import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useOutletContext } from 'react-router-dom'
import { AlertTriangle, Download, Eye, EyeOff, LayoutGrid, List, Pencil, Plus, Search, Trash2, X } from 'lucide-react'
import ProductModal from '../../components/products/ProductModal'
import ConfirmDialog from '../../components/ConfirmDialog'
import { Empty, Hero, Skeletons } from '../../components/catalogue/CatalogueUI'
import { fmtInt } from '../../components/catalogue/format'
import { useCatalogueProduits } from '../../features/produits/useCatalogueProduits'

const STATUTS = [
  { value: '', label: 'Tous' },
  { value: 'actif', label: 'Actifs' },
  { value: 'inactif', label: 'Inactifs' },
  { value: 'a_tarifer', label: 'À tarifer' },
  { value: 'rupture', label: 'En rupture' },
]

const fmtPrice = (n) => new Intl.NumberFormat('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(n)

function Badges({ p }) {
  return (
    <>
      {!p.actif ? <span className="cx-pill cx-pill-gray">Inactif</span> : null}
      {p.actif && p.stock <= 0 ? <span className="cx-pill cx-pill-amber">Rupture</span> : null}
    </>
  )
}

function Price({ p }) {
  return p.prix > 0 ? (
    <span className="cx-price">
      {fmtPrice(p.prix)} <small>DH</small>
    </span>
  ) : (
    <span className="cx-price-missing">À tarifer</span>
  )
}

function Tools({ p, onEdit, onToggle, onDelete, className }) {
  return (
    <div className={className} onClick={(e) => e.stopPropagation()}>
      <button className="cx-icon-btn" type="button" title="Modifier" onClick={() => onEdit(p)}>
        <Pencil size={15} />
      </button>
      <button className="cx-icon-btn" type="button" title={p.actif ? 'Désactiver' : 'Activer'} onClick={() => onToggle(p)}>
        {p.actif ? <EyeOff size={15} /> : <Eye size={15} />}
      </button>
      <button className="cx-icon-btn cx-icon-btn-danger" type="button" title="Supprimer" onClick={() => onDelete(p)}>
        <Trash2 size={15} />
      </button>
    </div>
  )
}

function pageList(page, last) {
  const set = new Set([1, last, page - 1, page, page + 1].filter((n) => n >= 1 && n <= last))
  const sorted = [...set].sort((a, b) => a - b)
  const out = []
  sorted.forEach((n, i) => {
    if (i && n - sorted[i - 1] > 1) out.push('…' + n)
    out.push(n)
  })
  return out
}

export default function Produits() {
  const navigate = useNavigate()
  const outlet = useOutletContext() || {}
  const c = useCatalogueProduits()
  const { filters, setFilter } = c

  // Recherche : saisie locale, envoyée au serveur après une courte pause.
  const [q, setQ] = useState(filters.q)
  const first = useRef(true)
  useEffect(() => {
    if (first.current) {
      first.current = false
      return undefined
    }
    const t = setTimeout(() => setFilter({ q: q.trim() }), 350)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [q])
  // La recherche de la barre du haut alimente aussi ce champ.
  useEffect(() => {
    if (outlet.search != null && outlet.search !== '' && outlet.search !== q) setQ(outlet.search)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [outlet.search])

  const sousCat = c.sousCategories.find((s) => String(s.id) === String(filters.sous_categorie)) || null
  // Si on arrive par une sous-catégorie, on déduit sa catégorie et sa famille.
  const categorieId = filters.categorie || (sousCat ? String(sousCat.categorie_id) : '')
  const categorie = c.categories.find((x) => String(x.id) === String(categorieId)) || null
  const familleId = filters.famille || (categorie ? String(categorie.famille_id) : '')
  const famille = c.familles.find((x) => String(x.id) === String(familleId)) || null

  const catOptions = useMemo(
    () => c.categories.filter((x) => !familleId || String(x.famille_id) === String(familleId)),
    [c.categories, familleId]
  )
  const scOptions = useMemo(
    () => c.sousCategories.filter((x) => !categorieId || String(x.categorie_id) === String(categorieId)),
    [c.sousCategories, categorieId]
  )

  const scope = sousCat || categorie || famille
  const scopeName = sousCat ? sousCat.name_fr || sousCat.nom : categorie ? categorie.name_fr || categorie.nom : famille?.nom_fr
  const scopeAr = sousCat ? sousCat.name_ar : categorie ? categorie.name_ar : famille?.nom_ar

  const crumbs = [{ label: 'Catalogue', to: '/admin/familles' }]
  if (famille) crumbs.push({ label: famille.nom_fr, to: `/admin/familles/${famille.id}/categories` })
  if (categorie) crumbs.push({ label: categorie.name_fr || categorie.nom, to: `/admin/categories/${categorie.id}` })
  crumbs.push({ label: sousCat ? sousCat.name_fr || sousCat.nom : 'Produits' })

  const hasFilters = !!(filters.q || familleId || categorieId || filters.sous_categorie || filters.statut)
  const s = c.stats

  const openEdit = (p) => c.setModal({ mode: 'edit', product: p })
  const openDetails = (p) => navigate(`/admin/produits/${p.id}`)

  return (
    <section className="cx">
      <Hero
        crumbs={crumbs}
        image={scope?.image}
        title={scope ? scopeName : 'Produits'}
        titleAr={scope ? scopeAr : 'المنتجات'}
        subtitle={
          hasFilters
            ? `${fmtInt(c.meta.total)} produit(s) correspondent à votre sélection.`
            : 'Tout le catalogue : recherchez, filtrez, tarifez et activez vos produits.'
        }
        stats={
          s
            ? [
                { label: 'Produits', value: fmtInt(s.total) },
                { label: 'Actifs', value: fmtInt(s.actifs) },
                { label: 'À tarifer', value: fmtInt(s.a_tarifer), warn: s.a_tarifer > 0 },
                { label: 'En rupture', value: fmtInt(s.rupture) },
                { label: 'Marques', value: fmtInt(s.marques) },
              ]
            : []
        }
        actions={
          <>
            <button className="cx-btn cx-btn-ghost-light" type="button" onClick={c.exportProducts}>
              <Download size={16} /> Exporter
            </button>
            <button className="cx-btn cx-btn-primary" type="button" onClick={() => c.setModal({ mode: 'create' })}>
              <Plus size={16} /> Ajouter un produit
            </button>
          </>
        }
      />

      {c.error ? <div className="cx-alert">{c.error}</div> : null}

      <div className="cx-toolbar">
        <label className="cx-search">
          <Search size={18} color="#94a3b8" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Nom, marque, code EAN, الاسم…" />
          {q ? (
            <button className="cx-icon-btn" type="button" onClick={() => setQ('')} aria-label="Effacer" style={{ width: 28, height: 28 }}>
              <X size={14} />
            </button>
          ) : null}
        </label>

        <select
          className="cx-select"
          value={familleId}
          onChange={(e) => setFilter({ famille: e.target.value, categorie: '', sous_categorie: '' })}
        >
          <option value="">Toutes les familles</option>
          {c.familles.map((f) => (
            <option key={f.id} value={f.id}>
              {f.nom_fr}
            </option>
          ))}
        </select>

        <select
          className="cx-select"
          value={categorieId}
          onChange={(e) => setFilter({ famille: familleId, categorie: e.target.value, sous_categorie: '' })}
        >
          <option value="">Toutes les catégories</option>
          {catOptions.map((x) => (
            <option key={x.id} value={x.id}>
              {x.name_fr || x.nom}
            </option>
          ))}
        </select>

        <select
          className="cx-select"
          value={filters.sous_categorie}
          onChange={(e) => setFilter({ famille: familleId, categorie: categorieId, sous_categorie: e.target.value })}
        >
          <option value="">Toutes les sous-catégories</option>
          {scOptions.map((x) => (
            <option key={x.id} value={x.id}>
              {x.name_fr || x.nom}
            </option>
          ))}
        </select>

        <select className="cx-select" value={filters.sort} onChange={(e) => setFilter({ sort: e.target.value === 'nom' ? '' : e.target.value })}>
          <option value="nom">Trier : nom A→Z</option>
          <option value="recent">Plus récents</option>
          <option value="prix_asc">Prix croissant</option>
          <option value="prix_desc">Prix décroissant</option>
        </select>

        <div className="cx-seg" role="group" aria-label="Affichage">
          <button className={c.view === 'grid' ? 'on' : ''} type="button" onClick={() => c.setView('grid')} title="Grille">
            <LayoutGrid size={17} />
          </button>
          <button className={c.view === 'list' ? 'on' : ''} type="button" onClick={() => c.setView('list')} title="Liste">
            <List size={17} />
          </button>
        </div>
      </div>

      <div className="cx-chips">
        {STATUTS.map((st) => (
          <button
            key={st.value || 'all'}
            className={`cx-chip ${filters.statut === st.value ? 'on' : ''}`}
            type="button"
            onClick={() => setFilter({ statut: st.value })}
          >
            {st.label}
            {s && st.value === 'a_tarifer' ? <span className="cx-chip-count">{fmtInt(s.a_tarifer)}</span> : null}
            {s && st.value === 'rupture' ? <span className="cx-chip-count">{fmtInt(s.rupture)}</span> : null}
          </button>
        ))}
        {hasFilters ? (
          <button
            className="cx-chip"
            type="button"
            onClick={() => {
              setQ('')
              outlet.setSearch?.('')
              setFilter({ q: '', famille: '', categorie: '', sous_categorie: '', statut: '' })
            }}
          >
            <X size={14} /> Effacer les filtres
          </button>
        ) : null}
      </div>

      {s && s.a_tarifer > 0 && !filters.statut ? (
        <div className="cx-note">
          <AlertTriangle size={18} style={{ flexShrink: 0 }} />
          <div>
            <b>{fmtInt(s.a_tarifer)} produit(s) n’ont pas encore de prix de vente.</b> Ils viennent du catalogue importé (Open Food Facts) et
            restent inactifs à la caisse tant qu’ils ne sont pas tarifés et activés.{' '}
            <a href="#" onClick={(e) => (e.preventDefault(), setFilter({ statut: 'a_tarifer' }))}>
              Voir la liste
            </a>
          </div>
        </div>
      ) : null}

      {c.view === 'grid' ? (
        <div className="cx-products">
          {c.loading ? <Skeletons count={12} height={330} /> : null}
          {!c.loading && c.items.length === 0 ? (
            <Empty title="Aucun produit">{hasFilters ? 'Aucun produit ne correspond à ces filtres.' : 'Le catalogue est vide.'}</Empty>
          ) : null}
          {!c.loading &&
            c.items.map((p) => (
              <article key={p.id} className="cx-product" tabIndex={0} onClick={() => openDetails(p)} onKeyDown={(e) => e.key === 'Enter' && openDetails(p)}>
                <div className="cx-product-media">
                  {p.img ? <img src={p.img} alt="" loading="lazy" /> : <div className="cx-card-fallback">{(p.nom || '?')[0]}</div>}
                  <div className="cx-product-badges">
                    <Badges p={p} />
                  </div>
                  <Tools className="cx-product-tools" p={p} onEdit={openEdit} onToggle={c.toggleActif} onDelete={c.setToDelete} />
                </div>
                <div className="cx-product-body">
                  <div className="cx-product-brand">{p.marqueName}</div>
                  <div className="cx-product-name" title={p.name_fr || p.nom}>
                    {p.name_fr || p.nom}
                  </div>
                  <div className="cx-product-path">{p.subCategoryName}</div>
                  <div className="cx-product-foot">
                    <Price p={p} />
                    <span className="cx-ean">{p.code_article}</span>
                  </div>
                </div>
              </article>
            ))}
        </div>
      ) : (
        <div className="cx-table">
          <div className="cx-row cx-row-head">
            <span />
            <span>Produit</span>
            <span>Classement</span>
            <span>Code EAN</span>
            <span>Prix</span>
            <span>Stock</span>
            <span />
          </div>
          {c.loading ? <div style={{ padding: 24, color: '#64748b' }}>Chargement…</div> : null}
          {!c.loading && c.items.length === 0 ? <div style={{ padding: 24, color: '#64748b' }}>Aucun produit.</div> : null}
          {!c.loading &&
            c.items.map((p) => (
              <div key={p.id} className="cx-row" onClick={() => openDetails(p)}>
                {p.img ? <img src={p.img} alt="" loading="lazy" /> : <span />}
                <div style={{ minWidth: 0 }}>
                  <div className="cx-product-brand">{p.marqueName}</div>
                  <div style={{ fontWeight: 650, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{p.name_fr || p.nom}</div>
                  {p.name_ar ? (
                    <div dir="rtl" style={{ fontSize: 12.5, color: '#64748b', textAlign: 'left' }}>
                      {p.name_ar}
                    </div>
                  ) : null}
                </div>
                <div className="cx-product-path" title={`${p.categoryName} › ${p.subCategoryName}`}>
                  {p.categoryName}
                  <br />
                  {p.subCategoryName}
                </div>
                <span className="cx-ean">{p.code_article}</span>
                <Price p={p} />
                <span style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
                  {p.stock > 0 ? fmtInt(p.stock) : null}
                  <Badges p={p} />
                </span>
                <Tools className="cx-row-actions" p={p} onEdit={openEdit} onToggle={c.toggleActif} onDelete={c.setToDelete} />
              </div>
            ))}
        </div>
      )}

      {c.meta.total > 0 ? (
        <div className="cx-pager">
          <span>
            {fmtInt(c.meta.from)}–{fmtInt(c.meta.to)} sur {fmtInt(c.meta.total)} produits
          </span>
          {c.meta.last_page > 1 ? (
            <div className="cx-pager-btns">
              <button className="cx-page" type="button" disabled={c.page <= 1} onClick={() => c.setPage(c.page - 1)}>
                ‹
              </button>
              {pageList(c.page, c.meta.last_page).map((n) =>
                typeof n === 'string' ? (
                  <span key={n} style={{ alignSelf: 'center', padding: '0 4px' }}>
                    …
                  </span>
                ) : (
                  <button key={n} className={`cx-page ${n === c.page ? 'on' : ''}`} type="button" onClick={() => c.setPage(n)}>
                    {n}
                  </button>
                )
              )}
              <button className="cx-page" type="button" disabled={c.page >= c.meta.last_page} onClick={() => c.setPage(c.page + 1)}>
                ›
              </button>
            </div>
          ) : null}
        </div>
      ) : null}

      <ProductModal
        key={`${c.modal?.mode || 'closed'}-${c.modal?.product?.id || 'new'}`}
        open={!!c.modal}
        mode={c.modal?.mode || 'create'}
        initialValues={c.modal?.mode === 'edit' ? c.modal.product : sousCat ? { sous_categorie_id: sousCat.id } : null}
        sousCategories={c.sousCategories}
        unites={c.unites}
        marques={c.marques}
        onClose={() => c.setModal(null)}
        onSubmit={c.modal?.mode === 'edit' ? c.updateProduct : c.addProduct}
      />

      <ConfirmDialog
        open={!!c.toDelete}
        title="Supprimer le produit"
        message={`Supprimer « ${c.toDelete?.name_fr || c.toDelete?.nom || ''} » ?`}
        confirmLabel={c.submitting ? 'Suppression…' : 'Supprimer'}
        onConfirm={c.confirmDelete}
        onCancel={() => c.setToDelete(null)}
      />
    </section>
  )
}

