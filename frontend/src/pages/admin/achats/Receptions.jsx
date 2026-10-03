import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Plus, Search } from 'lucide-react'
import { apiFetch } from '../../../lib/api'
import { Hero } from '../../../components/catalogue/CatalogueUI'
import { fmtInt } from '../../../components/catalogue/format'
import { dateFr, money } from '../../../components/achats/format'
import '../../../styles/catalogue.css'
import '../../../styles/achats.css'

/** Bons de réception = entrées de stock fournisseurs. */
export default function Receptions() {
  const navigate = useNavigate()
  const [q, setQ] = useState('')
  const [impaye, setImpaye] = useState(false)
  const [du, setDu] = useState('')
  const [au, setAu] = useState('')
  const [page, setPage] = useState(1)
  const [res, setRes] = useState(null)

  const load = useCallback(async () => {
    const qs = new URLSearchParams({ page: String(page), per_page: '30' })
    if (q.trim()) qs.set('q', q.trim())
    if (impaye) qs.set('impaye', '1')
    if (du) qs.set('du', du)
    if (au) qs.set('au', au)
    setRes(await apiFetch(`/api/achats/receptions?${qs}`))
  }, [page, q, impaye, du, au])

  useEffect(() => {
    const t = setTimeout(() => load().catch(() => {}), q ? 300 : 0)
    return () => clearTimeout(t)
  }, [load, q])

  const s = res?.stats

  return (
    <section className="cx">
      <Hero
        crumbs={[{ label: 'Achats' }]}
        title="Bons de réception"
        titleAr="وصولات الاستلام"
        subtitle="Chaque réception entre la marchandise en stock et fixe le prix d’achat des articles."
        stats={
          s
            ? [
                { label: 'Réceptions ce mois', value: fmtInt(s.mois_nombre) },
                { label: 'Achats du mois (DH)', value: money(s.mois_montant) },
                { label: 'Crédit fournisseurs (DH)', value: money(s.credit_total), warn: s.credit_total > 0 },
              ]
            : []
        }
        actions={
          <button className="cx-btn cx-btn-primary" type="button" onClick={() => navigate('/admin/achats/receptions/nouvelle')}>
            <Plus size={16} /> Nouvelle réception
          </button>
        }
      />

      <div className="cx-toolbar">
        <label className="cx-search">
          <Search size={18} color="#94a3b8" />
          <input value={q} onChange={(e) => (setQ(e.target.value), setPage(1))} placeholder="N° de réception, BL fournisseur, fournisseur…" />
        </label>
        <label className="ax-field" style={{ flexDirection: 'row', alignItems: 'center' }}>
          Du <input type="date" value={du} onChange={(e) => (setDu(e.target.value), setPage(1))} />
        </label>
        <label className="ax-field" style={{ flexDirection: 'row', alignItems: 'center' }}>
          Au <input type="date" value={au} onChange={(e) => (setAu(e.target.value), setPage(1))} />
        </label>
      </div>
      <div className="cx-chips">
        <button className={`cx-chip ${!impaye ? 'on' : ''}`} type="button" onClick={() => (setImpaye(false), setPage(1))}>
          Toutes
        </button>
        <button className={`cx-chip ${impaye ? 'on' : ''}`} type="button" onClick={() => (setImpaye(true), setPage(1))}>
          Non soldées
        </button>
      </div>

      <div className="ax-table-wrap">
        <table className="ax-table">
          <thead>
            <tr>
              <th>N°</th>
              <th>Date</th>
              <th>Fournisseur</th>
              <th>BL fournisseur</th>
              <th>Bon de commande</th>
              <th className="ax-num">Lignes</th>
              <th className="ax-num">Total (DH)</th>
              <th className="ax-num">Payé</th>
              <th>Règlement</th>
            </tr>
          </thead>
          <tbody>
            {!res ? (
              <tr className="ax-empty-row">
                <td colSpan={9}>Chargement…</td>
              </tr>
            ) : null}
            {res && !res.data?.length ? (
              <tr className="ax-empty-row">
                <td colSpan={9}>Aucune réception pour ces critères.</td>
              </tr>
            ) : null}
            {res?.data?.map((r) => (
              <tr key={r.id} className="ax-click" onClick={() => navigate(`/admin/achats/receptions/${r.id}`)}>
                <td className="ax-strong">{r.numero}</td>
                <td>{dateFr(r.date_reception)}</td>
                <td>{r.fournisseur?.nom}</td>
                <td className="ax-muted">{r.reference_fournisseur || '—'}</td>
                <td className="ax-muted">{r.commande?.numero || 'Directe'}</td>
                <td className="ax-num">{r.lignes_count}</td>
                <td className="ax-num ax-strong">{money(r.total)}</td>
                <td className="ax-num">{money(r.montant_paye)}</td>
                <td>
                  {r.reste > 0 ? <span className="ax-badge ax-st-du">Reste {money(r.reste)}</span> : <span className="ax-badge ax-st-paye">Soldée</span>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {res?.last_page > 1 ? (
        <div className="cx-pager">
          <span>
            {res.from}–{res.to} sur {res.total}
          </span>
          <div className="cx-pager-btns">
            <button className="cx-page" type="button" disabled={page <= 1} onClick={() => setPage(page - 1)}>
              ‹
            </button>
            <button className="cx-page on" type="button">
              {page}
            </button>
            <button className="cx-page" type="button" disabled={page >= res.last_page} onClick={() => setPage(page + 1)}>
              ›
            </button>
          </div>
        </div>
      ) : null}
    </section>
  )
}
