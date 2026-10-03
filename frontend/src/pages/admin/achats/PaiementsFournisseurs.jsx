import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { apiFetch } from '../../../lib/api'
import { Hero } from '../../../components/catalogue/CatalogueUI'
import { dateFr, modeLabel, money } from '../../../components/achats/format'
import '../../../styles/catalogue.css'
import '../../../styles/achats.css'

/** Historique des règlements versés aux fournisseurs. */
export default function PaiementsFournisseurs() {
  const navigate = useNavigate()
  const [fournisseurs, setFournisseurs] = useState([])
  const [fournisseur, setFournisseur] = useState('')
  const [page, setPage] = useState(1)
  const [res, setRes] = useState(null)

  useEffect(() => {
    apiFetch('/api/fournisseurs?per_page=1000').then((r) => setFournisseurs(r.data || [])).catch(() => {})
  }, [])

  const load = useCallback(async () => {
    const qs = new URLSearchParams({ page: String(page), per_page: '40' })
    if (fournisseur) qs.set('fournisseur_id', fournisseur)
    setRes(await apiFetch(`/api/achats/paiements?${qs}`))
  }, [page, fournisseur])

  useEffect(() => {
    const t = setTimeout(() => load().catch(() => {}), 0)
    return () => clearTimeout(t)
  }, [load])

  const totalPage = (res?.data || []).reduce((s, p) => s + Number(p.montant || 0), 0)

  return (
    <section className="cx">
      <Hero
        crumbs={[{ label: 'Achats' }]}
        title="Paiements fournisseurs"
        titleAr="أداءات المورّدين"
        subtitle="Historique de tous les règlements : à la réception ou ultérieurs."
        stats={[{ label: 'Total de la page (DH)', value: money(totalPage) }]}
      />
      <div className="cx-toolbar">
        <select className="cx-select" value={fournisseur} onChange={(e) => (setFournisseur(e.target.value), setPage(1))}>
          <option value="">Tous les fournisseurs</option>
          {fournisseurs.map((f) => (
            <option key={f.id} value={f.id}>
              {f.nom}
            </option>
          ))}
        </select>
      </div>
      <div className="ax-table-wrap">
        <table className="ax-table">
          <thead>
            <tr>
              <th>Date</th>
              <th>Fournisseur</th>
              <th>Mode</th>
              <th>Référence</th>
              <th>Réception</th>
              <th>Note</th>
              <th className="ax-num">Montant (DH)</th>
            </tr>
          </thead>
          <tbody>
            {res && !res.data?.length ? (
              <tr className="ax-empty-row">
                <td colSpan={7}>Aucun règlement.</td>
              </tr>
            ) : null}
            {res?.data?.map((p) => (
              <tr key={p.id} className="ax-click" onClick={() => navigate(`/admin/fournisseurs/${p.fournisseur_id}`)}>
                <td>{dateFr(p.date_paiement)}</td>
                <td className="ax-strong">{p.fournisseur?.nom}</td>
                <td>{modeLabel(p.mode)}</td>
                <td>{p.reference || '—'}</td>
                <td>{p.reception?.numero || '—'}</td>
                <td className="ax-muted">{p.note}</td>
                <td className="ax-num ax-strong ax-credit">{money(p.montant)}</td>
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
