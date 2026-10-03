import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { ArrowDown, ArrowUp, ArrowUpDown, Download, Search, X } from 'lucide-react'
import { apiFetch } from '../../lib/api'
import { toast } from '../../lib/toast'
import { Hero } from '../../components/catalogue/CatalogueUI'
import { fmtInt, listOf } from '../../components/catalogue/format'
import { json, money } from '../../components/achats/format'
import '../../styles/achats.css'
import '../../styles/tarifs.css'

const STATUTS = [
  { value: '', label: 'Tous' },
  { value: 'tarife', label: 'Tarifés', stat: 'tarifes' },
  { value: 'a_tarifer', label: 'À tarifer', stat: 'a_tarifer' },
  { value: 'promo', label: 'En promo', stat: 'promo' },
  { value: 'marge_faible', label: 'Marge < 10 %' },
  { value: 'perte', label: 'Vendus à perte', stat: 'perte' },
  { value: 'sans_achat', label: 'Sans prix d’achat' },
]

/** Colonne triable → [tri croissant, tri décroissant] côté API. */
const SORTS = {
  nom: ['nom', 'nom'],
  achat: ['achat_desc', 'achat_desc'],
  vente: ['vente_asc', 'vente_desc'],
  marge: ['marge_asc', 'marge_desc'],
}

const num = (v) => {
  if (v === '' || v == null) return null
  const n = Number(String(v).replace(',', '.').replace(/\s/g, ''))
  return Number.isFinite(n) && n >= 0 ? Math.round(n * 100) / 100 : NaN
}

const show = (n) => (Number(n) > 0 ? Number(n).toFixed(2).replace('.', ',') : '')

const margeOf = (achat, vente) => (vente > 0 ? ((vente - achat) / vente) * 100 : null)

function Marge({ achat, vente }) {
  const m = margeOf(achat, vente)
  if (m == null || achat <= 0) return <span className="tx-marge tx-m-none">—</span>
  const tone = m < 0 ? 'neg' : m < 10 ? 'low' : m > 40 ? 'high' : 'ok'
  return (
    <span>
      <span className={`tx-marge tx-m-${tone}`}>{m.toFixed(1)} %</span>
      <span className="tx-gain">{money(vente - achat)} DH</span>
    </span>
  )
}

function SortTh({ k, sort, onSort, children, className = '' }) {
  const [asc, desc] = SORTS[k]
  const on = sort === asc || sort === desc
  const Icon = !on ? ArrowUpDown : sort === desc && asc !== desc ? ArrowDown : ArrowUp
  return (
    <th className={`tx-sort ${on ? 'tx-sorted' : ''} ${className}`} onClick={() => onSort(on && sort === asc && asc !== desc ? desc : asc)}>
      {children}
      <Icon size={12} className="tx-arrow" />
    </th>
  )
}

/** Cellule de prix modifiable : Entrée ou sortie du champ = enregistrement ; Échap = annuler. */
function PriceCell({ value, field, row, onSave, variant = '', placeholder = '0,00' }) {
  const [v, setV] = useState(show(value))
  const [state, setState] = useState('')
  // Le parent remonte la cellule (key) quand la valeur enregistrée change.
  const orig = useRef(value)

  async function commit() {
    const n = num(v)
    if (Number.isNaN(n)) {
      setState('error')
      toast({ type: 'error', message: 'Prix invalide.' })
      return
    }
    if ((n ?? 0) === (Number(orig.current) || 0)) return
    setState('saving')
    try {
      await onSave(row, field, n)
      setState('saved')
      setTimeout(() => setState(''), 900)
    } catch (e) {
      setState('error')
      toast({ type: 'error', message: e?.message || 'Enregistrement impossible' })
    }
  }

  const empty = !(Number(value) > 0) && !v
  return (
    <span className={`tx-cell ${variant} ${empty && field === 'prix_vente' ? 'tx-cell-empty' : ''} ${state ? `tx-cell-${state}` : ''}`}>
      <input
        value={v}
        inputMode="decimal"
        placeholder={field === 'prix_vente' ? 'À fixer' : placeholder}
        onChange={(e) => setV(e.target.value)}
        onFocus={(e) => e.target.select()}
        onBlur={commit}
        onKeyDown={(e) => {
          if (e.key === 'Enter') {
            e.preventDefault()
            const all = [...document.querySelectorAll(`input[data-field="${field}"]`)]
            const next = all[all.indexOf(e.currentTarget) + 1]
            e.currentTarget.blur()
            // Même colonne, ligne suivante : comme un tableur.
            next?.focus()
          }
          if (e.key === 'Escape') {
            setV(show(orig.current))
            setState('')
            e.currentTarget.blur()
          }
        }}
        data-field={field}
        aria-label={field}
      />
    </span>
  )
}

export default function Prix() {
  const navigate = useNavigate()
  const [params, setParams] = useSearchParams()
  const f = {
    q: params.get('q') || '',
    famille: params.get('famille') || '',
    categorie: params.get('categorie') || '',
    sous_categorie: params.get('sous_categorie') || '',
    statut: params.get('statut') || '',
    sort: params.get('sort') || 'nom',
    page: Number(params.get('page') || 1),
    per: Number(params.get('par') || 50),
  }
  const set = useCallback(
    (patch) =>
      setParams(
        (prev) => {
          const next = new URLSearchParams(prev)
          Object.entries(patch).forEach(([k, v]) => (v === '' || v == null ? next.delete(k) : next.set(k, String(v))))
          if (!('page' in patch)) next.delete('page')
          return next
        },
        { replace: true }
      ),
    [setParams]
  )

  const [q, setQ] = useState(f.q)
  useEffect(() => {
    const t = setTimeout(() => q.trim() !== f.q && set({ q: q.trim() }), 350)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [q])

  const [familles, setFamilles] = useState([])
  const [categories, setCategories] = useState([])
  const [sousCategories, setSousCategories] = useState([])
  useEffect(() => {
    Promise.all([apiFetch('/api/familles?per_page=200'), apiFetch('/api/categories?per_page=1000'), apiFetch('/api/sous_categories?per_page=1000')])
      .then(([a, b, c]) => {
        setFamilles(listOf(a))
        setCategories(listOf(b))
        setSousCategories(listOf(c))
      })
      .catch(() => {})
  }, [])

  const qs = useMemo(() => {
    const s = new URLSearchParams({ page: String(f.page), per_page: String(f.per), sort: f.sort })
    if (f.q) s.set('q', f.q)
    if (f.famille) s.set('famille_id', f.famille)
    if (f.categorie) s.set('categorie_id', f.categorie)
    if (f.sous_categorie) s.set('sous_categorie_id', f.sous_categorie)
    if (f.statut) s.set('statut', f.statut)
    return s.toString()
  }, [f.page, f.per, f.sort, f.q, f.famille, f.categorie, f.sous_categorie, f.statut])

  const [res, setRes] = useState(null)
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState(() => new Set())
  const req = useRef(0)

  const load = useCallback(async () => {
    const id = ++req.current
    setLoading(true)
    try {
      const r = await apiFetch(`/api/tarifs?${qs}`)
      if (id !== req.current) return
      setRes(r)
      setRows(
        (r.data || []).map((a) => ({
          ...a,
          prix_achat: Number(a.prix_achat || 0),
          prix_vente: Number(a.prix_vente || 0),
          prix_gros: Number(a.prix_gros || 0),
          prix_promo: Number(a.prix_promo || 0),
        }))
      )
    } catch (e) {
      toast({ type: 'error', message: e?.message || 'Chargement impossible' })
    } finally {
      if (id === req.current) setLoading(false)
    }
  }, [qs])

  useEffect(() => {
    load()
  }, [load])
  useEffect(() => setSelected(new Set()), [qs])

  async function savePrice(row, field, value) {
    const r = await apiFetch(`/api/tarifs/${row.id}`, json('PUT', { [field]: value }))
    setRows((all) => all.map((x) => (x.id === row.id ? { ...x, [field]: Number(r.prix[field] || 0), actif: r.actif } : x)))
  }

  async function toggleActif(row) {
    try {
      const r = await apiFetch(`/api/tarifs/${row.id}`, json('PUT', { actif: !row.actif }))
      setRows((all) => all.map((x) => (x.id === row.id ? { ...x, actif: r.actif } : x)))
    } catch (e) {
      toast({ type: 'error', message: e?.message || 'Erreur' })
    }
  }

  // Actions groupées sur la sélection
  const [bulk, setBulk] = useState({ action: 'marge', valeur: '25', arrondi: '0.1' })
  const [bulkBusy, setBulkBusy] = useState(false)
  async function applyBulk() {
    setBulkBusy(true)
    try {
      const r = await apiFetch(
        '/api/tarifs/bulk',
        json('POST', { article_ids: [...selected], action: bulk.action, valeur: num(bulk.valeur) ?? 0, arrondi: Number(bulk.arrondi) })
      )
      toast({ type: 'success', message: `${r.modifies} produit(s) mis à jour${r.ignores ? ` — ${r.ignores} ignoré(s), prix manquant` : ''}.` })
      setSelected(new Set())
      await load()
    } catch (e) {
      toast({ type: 'error', message: e?.message || 'Erreur' })
    } finally {
      setBulkBusy(false)
    }
  }

  async function exportCsv() {
    try {
      const s = new URLSearchParams(qs)
      ;['page', 'per_page', 'sort'].forEach((k) => s.delete(k))
      const data = await apiFetch(`/api/tarifs/export?${s}`)
      const head = ['Code', 'Produit', 'Nom arabe', 'Marque', 'Catégorie', 'Sous-catégorie', 'Unité', 'Prix achat', 'Prix vente', 'Prix gros', 'Prix promo', 'Marge %', 'Actif']
      const lines = data.map((r) =>
        [r.code_article, r.nom, r.name_ar, r.marque, r.categorie, r.sous_categorie, r.unite, r.prix_achat, r.prix_vente, r.prix_gros, r.prix_promo,
          r.marge != null ? Number(r.marge).toFixed(1) : '', r.actif ? 'oui' : 'non']
          .map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`)
          .join(';')
      )
      const url = URL.createObjectURL(new Blob(['﻿' + [head.join(';'), ...lines].join('\n')], { type: 'text/csv;charset=utf-8;' }))
      const a = Object.assign(document.createElement('a'), { href: url, download: `tarifs_vente_${new Date().toISOString().slice(0, 10)}.csv` })
      a.click()
      URL.revokeObjectURL(url)
    } catch (e) {
      toast({ type: 'error', message: e?.message || 'Export impossible' })
    }
  }

  const catOptions = categories.filter((c) => !f.famille || String(c.famille_id) === f.famille)
  const scOptions = sousCategories.filter((x) => !f.categorie || String(x.categorie_id) === f.categorie)
  const s = res?.stats
  const allOnPage = rows.length > 0 && rows.every((r) => selected.has(r.id))
  const toggle = (id) =>
    setSelected((sel) => {
      const next = new Set(sel)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  const sortProps = { sort: f.sort, onSort: (v) => set({ sort: v === 'nom' ? '' : v }) }

  return (
    <section className="cx">
      <Hero
        crumbs={[{ label: 'Catalogue', to: '/admin/familles' }, { label: 'Tarifs de vente' }]}
        title="Tarifs de vente"
        titleAr="أسعار البيع"
        subtitle="Tous les prix au même endroit : modifiez directement dans le tableau, ou sélectionnez des produits pour appliquer une marge."
        stats={
          s
            ? [
                { label: 'Produits', value: fmtInt(s.total) },
                { label: 'Tarifés', value: fmtInt(s.tarifes) },
                { label: 'À tarifer', value: fmtInt(s.a_tarifer), warn: s.a_tarifer > 0 },
                { label: 'Marge moyenne', value: `${s.marge_moyenne || 0} %` },
                { label: 'En promotion', value: fmtInt(s.promo) },
                { label: 'Vendus à perte', value: fmtInt(s.perte), warn: s.perte > 0 },
              ]
            : []
        }
        actions={
          <button className="cx-btn cx-btn-ghost-light" type="button" onClick={exportCsv}>
            <Download size={16} /> Exporter (Excel)
          </button>
        }
      />

      <div className="cx-toolbar">
        <label className="cx-search">
          <Search size={18} color="#94a3b8" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Produit, marque, code-barres…" />
          {q ? (
            <button className="cx-icon-btn" style={{ width: 28, height: 28 }} type="button" onClick={() => setQ('')} aria-label="Effacer">
              <X size={14} />
            </button>
          ) : null}
        </label>
        <select className="cx-select" value={f.famille} onChange={(e) => set({ famille: e.target.value, categorie: '', sous_categorie: '' })}>
          <option value="">Toutes les familles</option>
          {familles.map((x) => (
            <option key={x.id} value={x.id}>
              {x.nom_fr}
            </option>
          ))}
        </select>
        <select className="cx-select" value={f.categorie} onChange={(e) => set({ categorie: e.target.value, sous_categorie: '' })}>
          <option value="">Toutes les catégories</option>
          {catOptions.map((x) => (
            <option key={x.id} value={x.id}>
              {x.name_fr || x.nom}
            </option>
          ))}
        </select>
        <select className="cx-select" value={f.sous_categorie} onChange={(e) => set({ sous_categorie: e.target.value })}>
          <option value="">Toutes les sous-catégories</option>
          {scOptions.map((x) => (
            <option key={x.id} value={x.id}>
              {x.name_fr || x.nom}
            </option>
          ))}
        </select>
      </div>

      <div className="cx-chips">
        {STATUTS.map((st) => (
          <button key={st.value || 'all'} className={`cx-chip ${f.statut === st.value ? 'on' : ''}`} type="button" onClick={() => set({ statut: st.value })}>
            {st.label}
            {s && st.stat ? <span className="cx-chip-count">{fmtInt(s[st.stat])}</span> : null}
          </button>
        ))}
      </div>

      {selected.size ? (
        <div className="tx-bulk">
          <b>{fmtInt(selected.size)} sélectionné(s)</b>
          <span className="tx-bulk-sep" />
          <select value={bulk.action} onChange={(e) => setBulk({ ...bulk, action: e.target.value })}>
            <option value="marge">Fixer la marge (% du prix de vente)</option>
            <option value="coef">Coefficient sur le prix d’achat (×)</option>
            <option value="hausse">Hausse / baisse du prix de vente (%)</option>
            <option value="promo">Remise promo (%) — 0 pour retirer</option>
            <option value="activer">Activer à la caisse</option>
            <option value="desactiver">Désactiver</option>
          </select>
          {['activer', 'desactiver'].includes(bulk.action) ? null : (
            <>
              <input value={bulk.valeur} onChange={(e) => setBulk({ ...bulk, valeur: e.target.value })} inputMode="decimal" aria-label="Valeur" />
              <select value={bulk.arrondi} onChange={(e) => setBulk({ ...bulk, arrondi: e.target.value })} title="Arrondi supérieur">
                <option value="0.01">Arrondi 0,01</option>
                <option value="0.05">Arrondi 0,05</option>
                <option value="0.1">Arrondi 0,10</option>
                <option value="0.5">Arrondi 0,50</option>
                <option value="1">Arrondi 1 DH</option>
              </select>
            </>
          )}
          <button className="cx-btn cx-btn-primary" type="button" disabled={bulkBusy} onClick={applyBulk}>
            {bulkBusy ? 'Application…' : 'Appliquer'}
          </button>
          <button className="tx-link" type="button" onClick={() => setSelected(new Set())}>
            Annuler la sélection
          </button>
        </div>
      ) : (
        <div className="tx-hint">
          Cliquez sur un prix pour le modifier : <kbd>Entrée</kbd> enregistre et passe à la ligne suivante, <kbd>Échap</kbd> annule. La marge se recalcule
          aussitôt.
        </div>
      )}

      <div className="tx-table-wrap">
        <table className="tx-table">
          <thead>
            <tr>
              <th className="tx-check">
                <input
                  type="checkbox"
                  checked={allOnPage}
                  aria-label="Tout sélectionner"
                  onChange={() =>
                    setSelected((sel) => {
                      const next = new Set(sel)
                      rows.forEach((r) => (allOnPage ? next.delete(r.id) : next.add(r.id)))
                      return next
                    })
                  }
                />
              </th>
              <SortTh k="nom" {...sortProps}>
                Produit
              </SortTh>
              <th>Code-barres</th>
              <th>Catégorie</th>
              <SortTh k="achat" className="tx-num" {...sortProps}>
                Prix d’achat
              </SortTh>
              <SortTh k="vente" className="tx-num" {...sortProps}>
                Prix de vente
              </SortTh>
              <th className="tx-num">Prix de gros</th>
              <th className="tx-num">Prix promo</th>
              <SortTh k="marge" className="tx-num" {...sortProps}>
                Marge
              </SortTh>
              <th className="tx-num">Stock</th>
              <th>Caisse</th>
            </tr>
          </thead>
          <tbody>
            {loading && !rows.length
              ? Array.from({ length: 8 }, (_, i) => (
                  <tr key={i}>
                    <td colSpan={11}>
                      <div className="cx-skel" style={{ minHeight: 34 }} />
                    </td>
                  </tr>
                ))
              : null}
            {!loading && !rows.length ? (
              <tr className="ax-empty-row">
                <td colSpan={11}>Aucun produit ne correspond à ces filtres.</td>
              </tr>
            ) : null}
            {rows.map((r) => {
              const sc = r.sous_categorie
              const marge = margeOf(r.prix_achat, r.prix_vente)
              return (
                <tr key={r.id} className={`${selected.has(r.id) ? 'tx-selected' : ''} ${!r.actif ? 'tx-off' : ''}`}>
                  <td className="tx-check tx-keep">
                    <input type="checkbox" checked={selected.has(r.id)} onChange={() => toggle(r.id)} aria-label="Sélectionner" />
                  </td>
                  <td>
                    <div className="tx-prod" onDoubleClick={() => navigate(`/admin/produits/${r.id}`)} title="Double-clic : fiche produit">
                      {r.image ? <img src={r.image} alt="" loading="lazy" /> : <span className="tx-noimg" />}
                      <div className="tx-prod-txt">
                        {r.marque?.nom ? <div className="tx-prod-brand">{r.marque.nom}</div> : null}
                        <div className="tx-prod-name" title={r.name_fr || r.nom}>
                          {r.name_fr || r.nom}
                        </div>
                        {r.name_ar ? <div className="tx-prod-ar">{r.name_ar}</div> : null}
                      </div>
                    </div>
                  </td>
                  <td className="tx-code">{r.code_article}</td>
                  <td className="tx-cat">
                    {sc?.categorie?.name_fr || sc?.categorie?.nom || '—'}
                    <small>{sc?.name_fr || sc?.nom}</small>
                  </td>
                  <td className="tx-num">
                    <PriceCell key={`prix_achat-${r.prix_achat}`} row={r} field="prix_achat" value={r.prix_achat} onSave={savePrice} />
                  </td>
                  <td className="tx-num">
                    <PriceCell key={`prix_vente-${r.prix_vente}`} row={r} field="prix_vente" value={r.prix_vente} onSave={savePrice} variant="tx-cell-vente" />
                  </td>
                  <td className="tx-num">
                    <PriceCell key={`prix_gros-${r.prix_gros}`} row={r} field="prix_gros" value={r.prix_gros} onSave={savePrice} placeholder="—" />
                  </td>
                  <td className="tx-num">
                    <PriceCell key={`prix_promo-${r.prix_promo}`} row={r} field="prix_promo" value={r.prix_promo} onSave={savePrice} variant="tx-cell-promo" placeholder="—" />
                  </td>
                  <td className="tx-num" title={marge != null ? `Taux de marque ${marge.toFixed(2)} %` : 'Prix manquant'}>
                    <Marge achat={r.prix_achat} vente={r.prix_vente} />
                  </td>
                  <td className="tx-num">{fmtInt(r.stock?.quantite)}</td>
                  <td className="tx-keep">
                    <button
                      className={`tx-switch ${r.actif ? 'on' : ''}`}
                      type="button"
                      onClick={() => toggleActif(r)}
                      title={r.actif ? 'Vendu en caisse — cliquer pour désactiver' : 'Inactif — cliquer pour activer'}
                      aria-pressed={r.actif}
                    />
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      {res ? (
        <div className="tx-foot">
          <span>
            {fmtInt(res.from || 0)}–{fmtInt(res.to || 0)} sur {fmtInt(res.total)} produits ·{' '}
            <select value={f.per} onChange={(e) => set({ par: e.target.value === '50' ? '' : e.target.value })}>
              {[25, 50, 100, 200].map((n) => (
                <option key={n} value={n}>
                  {n} par page
                </option>
              ))}
            </select>
          </span>
          {res.last_page > 1 ? (
            <div className="cx-pager-btns">
              <button className="cx-page" type="button" disabled={f.page <= 1} onClick={() => set({ page: f.page - 1 })}>
                ‹
              </button>
              {[...new Set([1, f.page - 1, f.page, f.page + 1, res.last_page])]
                .filter((n) => n >= 1 && n <= res.last_page)
                .sort((a, b) => a - b)
                .map((n, i, arr) => (
                  <span key={n} style={{ display: 'contents' }}>
                    {i > 0 && n - arr[i - 1] > 1 ? <span style={{ alignSelf: 'center' }}>…</span> : null}
                    <button className={`cx-page ${n === f.page ? 'on' : ''}`} type="button" onClick={() => set({ page: n })}>
                      {n}
                    </button>
                  </span>
                ))}
              <button className="cx-page" type="button" disabled={f.page >= res.last_page} onClick={() => set({ page: f.page + 1 })}>
                ›
              </button>
            </div>
          ) : null}
        </div>
      ) : null}
    </section>
  )
}
