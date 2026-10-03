import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { PackageCheck, Plus, Search } from 'lucide-react'
import { apiFetch } from '../../../lib/api'
import { Hero } from '../../../components/catalogue/CatalogueUI'
import { fmtInt } from '../../../components/catalogue/format'
import { STATUTS_BC, dateFr, money } from '../../../components/achats/format'
import '../../../styles/achats.css'

export default function BonsCommande() {
  const navigate = useNavigate()
  const [statut, setStatut] = useState('')
  const [q, setQ] = useState('')
  const [page, setPage] = useState(1)
  const [res, setRes] = useState(null)
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const qs = new URLSearchParams({ page: String(page), per_page: '30' })
      if (statut) qs.set('statut', statut)
      if (q.trim()) qs.set('q', q.trim())
      setRes(await apiFetch(`/api/achats/commandes?${qs}`))
    } finally {
      setLoading(false)
    }
  }, [page, statut, q])

  useEffect(() => {
    const t = setTimeout(load, q ? 300 : 0)
    return () => clearTimeout(t)
  }, [load, q])

  const stats = res?.stats || {}
  const n = (k) => Number(stats[k]?.n || 0)
  const enCours = n('confirmee') + n('partielle')
  const montantEnCours = Number(stats.confirmee?.montant || 0) + Number(stats.partielle?.montant || 0)

  return (
    <section className="cx">
      <Hero
        crumbs={[{ label: 'Achats' }]}
        title="Bons de commande"
        titleAr="طلبيات الشراء"
        subtitle="Commandez auprès de vos fournisseurs, puis réceptionnez la marchandise pour l’entrer en stock."
        stats={[
          { label: 'Brouillons', value: fmtInt(n('brouillon')) },
          { label: 'En attente de livraison', value: fmtInt(enCours), warn: enCours > 0 },
          { label: 'Montant attendu (DH)', value: money(montantEnCours) },
          { label: 'Reçus', value: fmtInt(n('recue')) },
        ]}
        actions={
          <>
            <button className="cx-btn cx-btn-ghost-light" type="button" onClick={() => navigate('/admin/achats/receptions/nouvelle')}>
              <PackageCheck size={16} /> Réception directe
            </button>
            <button className="cx-btn cx-btn-primary" type="button" onClick={() => navigate('/admin/achats/commandes/nouveau')}>
              <Plus size={16} /> Nouveau bon de commande
            </button>
          </>
        }
      />

      <div className="cx-toolbar">
        <label className="cx-search">
          <Search size={18} color="#94a3b8" />
          <input value={q} onChange={(e) => (setQ(e.target.value), setPage(1))} placeholder="N° de bon ou fournisseur…" />
        </label>
      </div>
      <div className="cx-chips">
        {[['', 'Tous'], ...Object.entries(STATUTS_BC)].map(([v, label]) => (
          <button key={v || 'all'} className={`cx-chip ${statut === v ? 'on' : ''}`} type="button" onClick={() => (setStatut(v), setPage(1))}>
            {label}
            {v ? <span className="cx-chip-count">{fmtInt(n(v))}</span> : null}
          </button>
        ))}
      </div>

      <div className="ax-table-wrap">
        <table className="ax-table">
          <thead>
            <tr>
              <th>N°</th>
              <th>Fournisseur</th>
              <th>Date</th>
              <th>Livraison prévue</th>
              <th className="ax-num">Lignes</th>
              <th className="ax-num">Total (DH)</th>
              <th>Statut</th>
            </tr>
          </thead>
          <tbody>
            {loading && !res ? (
              <tr className="ax-empty-row">
                <td colSpan={7}>Chargement…</td>
              </tr>
            ) : null}
            {res && !res.data?.length ? (
              <tr className="ax-empty-row">
                <td colSpan={7}>Aucun bon de commande. Créez le premier avec « Nouveau bon de commande ».</td>
              </tr>
            ) : null}
            {res?.data?.map((c) => (
              <tr key={c.id} className="ax-click" onClick={() => navigate(`/admin/achats/commandes/${c.id}`)}>
                <td className="ax-strong">{c.numero}</td>
                <td>{c.fournisseur?.nom || '—'}</td>
                <td>{dateFr(c.date_commande)}</td>
                <td>{dateFr(c.date_prevue)}</td>
                <td className="ax-num">{c.lignes_count}</td>
                <td className="ax-num ax-strong">{money(c.total)}</td>
                <td>
                  <span className={`ax-badge ax-st-${c.statut}`}>{STATUTS_BC[c.statut] || c.statut}</span>
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
