import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Plus, Search } from 'lucide-react'
import { apiFetch } from '../../lib/api'
import { Hero } from '../../components/catalogue/CatalogueUI'
import { fmtInt } from '../../components/catalogue/format'
import FournisseurForm from '../../components/achats/FournisseurForm'
import { dateFr, money } from '../../components/achats/format'
import '../../styles/catalogue.css'
import '../../styles/achats.css'

/** Fournisseurs et crédit fournisseur. */
export default function Fournisseurs() {
  const navigate = useNavigate()
  const [q, setQ] = useState('')
  const [credit, setCredit] = useState(false)
  const [page, setPage] = useState(1)
  const [res, setRes] = useState(null)
  const [form, setForm] = useState(false)

  const load = useCallback(async () => {
    const qs = new URLSearchParams({ page: String(page), per_page: '50' })
    if (q.trim()) qs.set('q', q.trim())
    if (credit) qs.set('avec_credit', '1')
    setRes(await apiFetch(`/api/fournisseurs?${qs}`))
  }, [page, q, credit])

  useEffect(() => {
    const t = setTimeout(() => load().catch(() => {}), q ? 300 : 0)
    return () => clearTimeout(t)
  }, [load, q])

  const s = res?.stats

  return (
    <section className="cx">
      <Hero
        crumbs={[{ label: 'Achats' }]}
        title="Fournisseurs"
        titleAr="المورّدون"
        subtitle="Vos fournisseurs, leurs achats et le crédit que vous leur devez."
        stats={
          s
            ? [
                { label: 'Fournisseurs', value: fmtInt(s.total) },
                { label: 'Actifs', value: fmtInt(s.actifs) },
                { label: 'Crédit total dû (DH)', value: money(s.credit_total), warn: s.credit_total > 0 },
                { label: 'Avec crédit', value: fmtInt(s.avec_credit) },
                { label: 'Plafond dépassé', value: fmtInt(s.depassement), warn: s.depassement > 0 },
              ]
            : []
        }
        actions={
          <button className="cx-btn cx-btn-primary" type="button" onClick={() => setForm(true)}>
            <Plus size={16} /> Nouveau fournisseur
          </button>
        }
      />

      <div className="cx-toolbar">
        <label className="cx-search">
          <Search size={18} color="#94a3b8" />
          <input value={q} onChange={(e) => (setQ(e.target.value), setPage(1))} placeholder="Nom, code, téléphone, ville, ICE…" />
        </label>
      </div>
      <div className="cx-chips">
        <button className={`cx-chip ${!credit ? 'on' : ''}`} type="button" onClick={() => (setCredit(false), setPage(1))}>
          Tous
        </button>
        <button className={`cx-chip ${credit ? 'on' : ''}`} type="button" onClick={() => (setCredit(true), setPage(1))}>
          Avec crédit <span className="cx-chip-count">{fmtInt(s?.avec_credit)}</span>
        </button>
      </div>

      <div className="ax-table-wrap">
        <table className="ax-table">
          <thead>
            <tr>
              <th>Fournisseur</th>
              <th>Contact</th>
              <th>Ville</th>
              <th className="ax-num">Réceptions</th>
              <th className="ax-num">Achats cumulés (DH)</th>
              <th>Dernière livraison</th>
              <th className="ax-num">Crédit dû (DH)</th>
            </tr>
          </thead>
          <tbody>
            {!res ? (
              <tr className="ax-empty-row">
                <td colSpan={7}>Chargement…</td>
              </tr>
            ) : null}
            {res && !res.data?.length ? (
              <tr className="ax-empty-row">
                <td colSpan={7}>Aucun fournisseur.</td>
              </tr>
            ) : null}
            {res?.data?.map((f) => {
              const depasse = f.plafond_credit && Number(f.solde) > Number(f.plafond_credit)
              return (
                <tr key={f.id} className="ax-click" onClick={() => navigate(`/admin/fournisseurs/${f.id}`)} style={f.actif ? null : { opacity: 0.6 }}>
                  <td>
                    <div className="ax-strong">{f.nom}</div>
                    <div className="ax-muted">{[f.code, f.ice && `ICE ${f.ice}`].filter(Boolean).join(' · ') || ' '}</div>
                  </td>
                  <td>
                    <div>{f.contact || '—'}</div>
                    <div className="ax-muted">{f.telephone}</div>
                  </td>
                  <td>{f.ville || '—'}</td>
                  <td className="ax-num">{fmtInt(f.receptions_count)}</td>
                  <td className="ax-num">{money(f.total_achats)}</td>
                  <td>{dateFr(f.derniere_reception)}</td>
                  <td className="ax-num">
                    {Number(f.solde) > 0 ? (
                      <span className={`ax-badge ${depasse ? 'ax-st-annulee' : 'ax-st-du'}`}>{money(f.solde)}</span>
                    ) : (
                      <span className="ax-badge ax-st-paye">0,00</span>
                    )}
                  </td>
                </tr>
              )
            })}
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

      {form ? (
        <FournisseurForm
          open
          onClose={() => setForm(false)}
          onSaved={(f) => {
            setForm(false)
            navigate(`/admin/fournisseurs/${f.id}`)
          }}
        />
      ) : null}
    </section>
  )
}
