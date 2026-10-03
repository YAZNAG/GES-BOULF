import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { Printer, Wallet } from 'lucide-react'
import { apiFetch } from '../../../lib/api'
import { toast } from '../../../lib/toast'
import { Hero } from '../../../components/catalogue/CatalogueUI'
import PaiementFournisseurModal from '../../../components/achats/PaiementFournisseurModal'
import { articleName, dateFr, modeLabel, money, qty } from '../../../components/achats/format'
import '../../../styles/catalogue.css'
import '../../../styles/achats.css'

export default function ReceptionDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [r, setR] = useState(null)
  const [payer, setPayer] = useState(false)

  const load = () =>
    apiFetch(`/api/achats/receptions/${id}`)
      .then(setR)
      .catch((e) => toast({ type: 'error', message: e.message }))
  useEffect(() => {
    load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id])

  if (!r) return <section className="cx">Chargement…</section>

  return (
    <section className="cx">
      <Hero
        crumbs={[{ label: 'Achats' }, { label: 'Réceptions', to: '/admin/achats/receptions' }, { label: r.numero }]}
        title={`Bon de réception ${r.numero}`}
        titleAr="وصل استلام"
        subtitle={`${r.fournisseur?.nom} · reçu le ${dateFr(r.date_reception)}${r.reference_fournisseur ? ` · BL ${r.reference_fournisseur}` : ''}${r.commande ? ` · commande ${r.commande.numero}` : ''}`}
        stats={[
          { label: 'Articles', value: String(r.lignes?.length || 0) },
          { label: 'Total (DH)', value: money(r.total) },
          { label: 'Payé (DH)', value: money(r.montant_paye) },
          { label: 'Reste dû (DH)', value: money(r.reste), warn: r.reste > 0 },
        ]}
        actions={
          <div className="ax-noprint" style={{ display: 'flex', gap: 8 }}>
            <button className="cx-btn cx-btn-ghost-light" type="button" onClick={() => window.print()}>
              <Printer size={16} /> Imprimer
            </button>
            {r.reste > 0 ? (
              <button className="cx-btn cx-btn-primary" type="button" onClick={() => setPayer(true)}>
                <Wallet size={16} /> Régler
              </button>
            ) : null}
          </div>
        }
      />

      <div className="ax-layout">
        <div className="ax-table-wrap">
          <table className="ax-table">
            <thead>
              <tr>
                <th>Article</th>
                <th className="ax-num">Quantité</th>
                <th className="ax-num">Prix d’achat</th>
                <th className="ax-num">Prix de vente fixé</th>
                <th className="ax-num">Total (DH)</th>
              </tr>
            </thead>
            <tbody>
              {r.lignes?.map((l) => (
                <tr key={l.id} className="ax-click" onClick={() => navigate(`/admin/produits/${l.article_id}`)}>
                  <td>
                    <div className="ax-prod">
                      {l.article?.image ? <img src={l.article.image} alt="" /> : <span className="ax-thumb" />}
                      <div>
                        <div className="ax-prod-name">{articleName(l.article)}</div>
                        <div className="ax-muted">{l.article?.code_article}</div>
                      </div>
                    </div>
                  </td>
                  <td className="ax-num">
                    {qty(l.quantite)} {l.article?.unite}
                  </td>
                  <td className="ax-num">{money(l.prix_achat)}</td>
                  <td className="ax-num">{l.prix_vente ? money(l.prix_vente) : '—'}</td>
                  <td className="ax-num ax-strong">{money(l.quantite * l.prix_achat)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <aside className="ax-sticky">
          <div className="ax-panel">
            <div className="ax-panel-title">Informations</div>
            <div className="ax-totals">
              <div className="ax-total-row">
                Fournisseur <b>{r.fournisseur?.nom}</b>
              </div>
              <div className="ax-total-row">
                Mode de paiement <b>{modeLabel(r.mode_paiement)}</b>
              </div>
              <div className="ax-total-row">
                Saisi par <b>{r.utilisateur?.nom || '—'}</b>
              </div>
              {r.note ? <div className="ax-muted">{r.note}</div> : null}
              <div className="ax-total-big">
                {money(r.total)} <span>DH</span>
              </div>
            </div>
          </div>
          <button className="cx-btn ax-noprint" type="button" style={{ width: '100%', marginTop: 12 }} onClick={() => navigate(`/admin/fournisseurs/${r.fournisseur_id}`)}>
            Voir la fiche fournisseur
          </button>
        </aside>
      </div>

      <PaiementFournisseurModal
        open={payer}
        fournisseur={r.fournisseur}
        reception={r}
        onClose={() => setPayer(false)}
        onDone={() => {
          setPayer(false)
          load()
        }}
      />
    </section>
  )
}
