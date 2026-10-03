import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { PackageCheck, Search } from 'lucide-react'
import { apiFetch } from '../../../lib/api'
import { Hero } from '../../../components/catalogue/CatalogueUI'
import { articleName, qty } from '../../../components/achats/format'
import '../../../styles/catalogue.css'
import '../../../styles/achats.css'

const MOTIFS = { achat: 'Achat (réception)', retour: 'Retour client', ajustement: 'Ajustement / inventaire', perte: 'Perte', don: 'Don', vente: 'Vente' }

/** Historique des entrées de stock (réceptions fournisseurs, retours, ajustements). */
export default function EntreesStock() {
  const navigate = useNavigate()
  const [q, setQ] = useState('')
  const [motif, setMotif] = useState('')
  const [du, setDu] = useState('')
  const [au, setAu] = useState('')
  const [page, setPage] = useState(1)
  const [res, setRes] = useState(null)

  const load = useCallback(async () => {
    const qs = new URLSearchParams({ type: 'entree', page: String(page), per_page: '40' })
    if (q.trim()) qs.set('q', q.trim())
    if (motif) qs.set('motif', motif)
    if (du) qs.set('du', du)
    if (au) qs.set('au', au)
    setRes(await apiFetch(`/api/m/mouvements?${qs}`))
  }, [page, q, motif, du, au])

  useEffect(() => {
    const t = setTimeout(() => load().catch(() => {}), q ? 300 : 0)
    return () => clearTimeout(t)
  }, [load, q])

  return (
    <section className="cx">
      <Hero
        crumbs={[{ label: 'Stock' }]}
        title="Entrées de stock"
        titleAr="مداخيل المخزون"
        subtitle="Toutes les quantités entrées en magasin : réceptions fournisseurs, retours et ajustements d’inventaire."
        actions={
          <button className="cx-btn cx-btn-primary" type="button" onClick={() => navigate('/admin/achats/receptions/nouvelle')}>
            <PackageCheck size={16} /> Nouvelle réception
          </button>
        }
      />
      <div className="cx-toolbar">
        <label className="cx-search">
          <Search size={18} color="#94a3b8" />
          <input value={q} onChange={(e) => (setQ(e.target.value), setPage(1))} placeholder="Produit ou code-barres…" />
        </label>
        <select className="cx-select" value={motif} onChange={(e) => (setMotif(e.target.value), setPage(1))}>
          <option value="">Tous les motifs</option>
          {['achat', 'retour', 'ajustement'].map((m) => (
            <option key={m} value={m}>
              {MOTIFS[m]}
            </option>
          ))}
        </select>
        <label className="ax-field" style={{ flexDirection: 'row', alignItems: 'center' }}>
          Du <input type="date" value={du} onChange={(e) => (setDu(e.target.value), setPage(1))} />
        </label>
        <label className="ax-field" style={{ flexDirection: 'row', alignItems: 'center' }}>
          Au <input type="date" value={au} onChange={(e) => (setAu(e.target.value), setPage(1))} />
        </label>
      </div>

      <div className="ax-table-wrap">
        <table className="ax-table">
          <thead>
            <tr>
              <th>Date</th>
              <th>Article</th>
              <th className="ax-num">Quantité</th>
              <th>Motif</th>
              <th>Fournisseur</th>
              <th>Référence</th>
              <th>Par</th>
            </tr>
          </thead>
          <tbody>
            {res && !res.data?.length ? (
              <tr className="ax-empty-row">
                <td colSpan={7}>Aucune entrée de stock.</td>
              </tr>
            ) : null}
            {res?.data?.map((m) => (
              <tr
                key={m.id}
                className={m.reference_type === 'reception' ? 'ax-click' : ''}
                onClick={() => m.reference_type === 'reception' && navigate(`/admin/achats/receptions/${m.reference_id}`)}
              >
                <td>{new Date(m.created_at).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' })}</td>
                <td>
                  <div className="ax-prod">
                    {m.article?.image ? <img src={m.article.image} alt="" loading="lazy" /> : <span className="ax-thumb" />}
                    <div>
                      <div className="ax-prod-name">{articleName(m.article)}</div>
                      <div className="ax-muted">{m.article?.code_article}</div>
                    </div>
                  </div>
                </td>
                <td className="ax-num ax-strong ax-credit">
                  +{qty(m.quantite)} <span className="ax-muted">{m.article?.unite}</span>
                </td>
                <td>{MOTIFS[m.motif] || m.motif}</td>
                <td>{m.fournisseur?.nom || '—'}</td>
                <td className="ax-muted">{m.note || '—'}</td>
                <td className="ax-muted">{m.utilisateur?.nom || '—'}</td>
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
              {page} / {res.last_page}
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
