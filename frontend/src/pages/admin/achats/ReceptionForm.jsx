import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { PackageCheck, Trash2 } from 'lucide-react'
import { apiFetch } from '../../../lib/api'
import { toast } from '../../../lib/toast'
import { Hero } from '../../../components/catalogue/CatalogueUI'
import ArticleSearch from '../../../components/achats/ArticleSearch'
import { MODES_PAIEMENT, articleName, json, money, qty, today } from '../../../components/achats/format'
import '../../../styles/catalogue.css'
import '../../../styles/achats.css'

let seq = 0
const line = (p) => ({ key: ++seq, prix_vente: '', ...p })

/**
 * Nouveau bon de réception (entrée de stock) :
 * - depuis un bon de commande (?commande=ID) : lignes pré-remplies avec le reste à recevoir ;
 * - ou direct : scan / recherche des articles.
 * Le prix d'achat saisi ici devient le prix d'achat de l'article ; le prix de vente est facultatif.
 */
export default function ReceptionForm() {
  const navigate = useNavigate()
  const [params] = useSearchParams()
  const commandeId = params.get('commande')
  const [commande, setCommande] = useState(null)
  const [fournisseurs, setFournisseurs] = useState([])
  const [form, setForm] = useState({ fournisseur_id: '', date_reception: today(), reference_fournisseur: '', note: '', montant_paye: '', mode_paiement: 'especes' })
  const [lines, setLines] = useState([])
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    apiFetch('/api/fournisseurs?per_page=1000&actif=1').then((r) => setFournisseurs(r.data || [])).catch(() => {})
  }, [])

  useEffect(() => {
    if (!commandeId) return
    apiFetch(`/api/achats/commandes/${commandeId}`)
      .then((c) => {
        setCommande(c)
        setForm((f) => ({ ...f, fournisseur_id: String(c.fournisseur_id) }))
        setLines(
          (c.lignes || [])
            .map((l) => {
              const reste = Math.max(0, Number(l.quantite) - Number(l.quantite_recue || 0))
              return line({
                article_id: l.article_id,
                article: l.article,
                ligne_commande_achat_id: l.id,
                commandee: reste,
                quantite: String(reste),
                prix_achat: String(l.prix_unitaire || l.article?.prix?.prix_achat || 0),
              })
            })
            .filter((l) => l.commandee > 0)
        )
      })
      .catch((e) => toast({ type: 'error', message: e.message }))
  }, [commandeId])

  function addArticle(a) {
    setLines((ls) => {
      const i = ls.findIndex((l) => l.article_id === a.id)
      if (i >= 0) {
        const next = [...ls]
        next[i] = { ...next[i], quantite: String(Number(next[i].quantite || 0) + 1) }
        return next
      }
      return [...ls, line({ article_id: a.id, article: a, quantite: '1', prix_achat: String(Number(a.prix?.prix_achat || 0) || '') })]
    })
  }
  const patch = (key, p) => setLines((ls) => ls.map((l) => (l.key === key ? { ...l, ...p } : l)))

  const total = useMemo(() => lines.reduce((s, l) => s + Number(l.quantite || 0) * Number(l.prix_achat || 0), 0), [lines])
  const paye = Math.min(Number(String(form.montant_paye).replace(',', '.')) || 0, total)
  const fournisseur = fournisseurs.find((f) => String(f.id) === String(form.fournisseur_id))

  async function submit() {
    if (!form.fournisseur_id) return toast({ type: 'error', message: 'Choisissez le fournisseur.' })
    const valid = lines.filter((l) => Number(l.quantite) > 0)
    if (!valid.length) return toast({ type: 'error', message: 'Aucune quantité reçue.' })
    if (valid.some((l) => l.prix_achat === '' || Number.isNaN(Number(l.prix_achat)))) {
      return toast({ type: 'error', message: 'Indiquez le prix d’achat de chaque article.' })
    }
    setBusy(true)
    try {
      const r = await apiFetch(
        '/api/achats/receptions',
        json('POST', {
          ...form,
          fournisseur_id: Number(form.fournisseur_id),
          commande_achat_id: commande?.id || null,
          montant_paye: paye,
          lignes: valid.map((l) => ({
            article_id: l.article_id,
            quantite: Number(l.quantite),
            prix_achat: Number(l.prix_achat),
            prix_vente: l.prix_vente === '' ? null : Number(l.prix_vente),
            ligne_commande_achat_id: l.ligne_commande_achat_id || null,
          })),
        })
      )
      toast({ type: 'success', message: `Réception ${r.numero} validée : stock et prix mis à jour.` })
      navigate(`/admin/achats/receptions/${r.id}`, { replace: true })
    } catch (e) {
      toast({ type: 'error', message: e.message })
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="cx">
      <Hero
        crumbs={[{ label: 'Achats' }, { label: 'Réceptions', to: '/admin/achats/receptions' }, { label: 'Nouvelle' }]}
        title="Nouvelle réception"
        titleAr="استلام سلعة"
        subtitle={commande ? `Réception du bon de commande ${commande.numero}` : 'Réception directe : scannez les articles livrés et saisissez leur prix d’achat.'}
        stats={[
          { label: 'Articles', value: String(lines.length) },
          { label: 'Total (DH)', value: money(total) },
          { label: 'Reste dû (DH)', value: money(total - paye), warn: total - paye > 0 },
        ]}
        actions={
          <button className="cx-btn cx-btn-primary" type="button" disabled={busy} onClick={submit}>
            <PackageCheck size={16} /> {busy ? 'Validation…' : 'Valider la réception'}
          </button>
        }
      />

      <div className="ax-layout">
        <div>
          <div className="ax-panel">
            <div className="ax-form">
              <label className="ax-field">
                Fournisseur *
                <select value={form.fournisseur_id} disabled={!!commande} onChange={(e) => setForm({ ...form, fournisseur_id: e.target.value })}>
                  <option value="">Choisir…</option>
                  {fournisseurs.map((f) => (
                    <option key={f.id} value={f.id}>
                      {f.nom}
                    </option>
                  ))}
                </select>
              </label>
              <label className="ax-field">
                Date de réception
                <input type="date" value={form.date_reception} onChange={(e) => setForm({ ...form, date_reception: e.target.value })} />
              </label>
              <label className="ax-field">
                N° BL / facture fournisseur
                <input value={form.reference_fournisseur} onChange={(e) => setForm({ ...form, reference_fournisseur: e.target.value })} placeholder="ex. BL-2026-778" />
              </label>
              <label className="ax-field ax-field-wide">
                Note
                <input value={form.note} onChange={(e) => setForm({ ...form, note: e.target.value })} placeholder="Colis abîmés, manquants…" />
              </label>
            </div>
          </div>

          <div className="ax-panel">
            <div className="ax-panel-title">
              Articles reçus
              <span className="ax-muted">Le prix d’achat saisi met à jour la fiche article.</span>
            </div>
            <div style={{ marginBottom: 12 }}>
              <ArticleSearch onPick={addArticle} />
            </div>
            <div className="ax-table-wrap">
              <table className="ax-table">
                <thead>
                  <tr>
                    <th>Article</th>
                    {commande ? <th className="ax-num">Attendu</th> : null}
                    <th className="ax-num">Qté reçue</th>
                    <th className="ax-num">Prix d’achat</th>
                    <th className="ax-num">Prix de vente</th>
                    <th className="ax-num">Total</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {!lines.length ? (
                    <tr className="ax-empty-row">
                      <td colSpan={7}>Scannez le premier article livré.</td>
                    </tr>
                  ) : null}
                  {lines.map((l) => {
                    const ancien = Number(l.article?.prix?.prix_achat || 0)
                    const nouveau = Number(l.prix_achat || 0)
                    const vente = Number(l.prix_vente || l.article?.prix?.prix_vente || 0)
                    return (
                      <tr key={l.key}>
                        <td>
                          <div className="ax-prod">
                            {l.article?.image ? <img src={l.article.image} alt="" /> : <span className="ax-thumb" />}
                            <div>
                              <div className="ax-prod-name">{articleName(l.article)}</div>
                              <div className="ax-muted">
                                {l.article?.code_article} · stock {qty(l.article?.stock?.quantite)}
                              </div>
                            </div>
                          </div>
                        </td>
                        {commande ? <td className="ax-num ax-muted">{qty(l.commandee)}</td> : null}
                        <td className="ax-num">
                          <input
                            className={`ax-in ${commande && Number(l.quantite) !== l.commandee ? 'ax-in-warn' : ''}`}
                            value={l.quantite}
                            inputMode="decimal"
                            onChange={(e) => patch(l.key, { quantite: e.target.value.replace(',', '.') })}
                          />
                        </td>
                        <td className="ax-num">
                          <input className="ax-in" value={l.prix_achat} inputMode="decimal" placeholder="0,00" onChange={(e) => patch(l.key, { prix_achat: e.target.value.replace(',', '.') })} />
                          {ancien > 0 && nouveau > 0 && Math.abs(ancien - nouveau) >= 0.01 ? (
                            <div className="ax-muted" style={{ color: nouveau > ancien ? '#dc2626' : '#16a34a' }}>
                              avant {money(ancien)}
                            </div>
                          ) : null}
                        </td>
                        <td className="ax-num">
                          <input
                            className="ax-in"
                            value={l.prix_vente}
                            inputMode="decimal"
                            placeholder={Number(l.article?.prix?.prix_vente) > 0 ? money(l.article.prix.prix_vente) : 'facultatif'}
                            onChange={(e) => patch(l.key, { prix_vente: e.target.value.replace(',', '.') })}
                          />
                          {vente > 0 && nouveau > 0 ? <div className="ax-muted">marge {(((vente - nouveau) / vente) * 100).toFixed(1)} %</div> : null}
                        </td>
                        <td className="ax-num ax-strong">{money(Number(l.quantite || 0) * nouveau)}</td>
                        <td>
                          <button className="cx-icon-btn cx-icon-btn-danger" type="button" onClick={() => setLines((ls) => ls.filter((x) => x.key !== l.key))} title="Retirer">
                            <Trash2 size={15} />
                          </button>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <aside className="ax-sticky">
          <div className="ax-panel">
            <div className="ax-panel-title">Règlement</div>
            <div className="ax-totals">
              <div className="ax-total-row">
                Total de la réception <b>{money(total)} DH</b>
              </div>
              <label className="ax-field">
                Payé maintenant
                <input value={form.montant_paye} inputMode="decimal" placeholder="0,00" onChange={(e) => setForm({ ...form, montant_paye: e.target.value })} />
              </label>
              <div style={{ display: 'flex', gap: 6 }}>
                <button className="cx-btn" type="button" style={{ flex: 1 }} onClick={() => setForm({ ...form, montant_paye: total.toFixed(2) })}>
                  Tout payer
                </button>
                <button className="cx-btn" type="button" style={{ flex: 1 }} onClick={() => setForm({ ...form, montant_paye: '' })}>
                  À crédit
                </button>
              </div>
              {paye > 0 ? (
                <label className="ax-field">
                  Mode de paiement
                  <select value={form.mode_paiement} onChange={(e) => setForm({ ...form, mode_paiement: e.target.value })}>
                    {MODES_PAIEMENT.map((m) => (
                      <option key={m.value} value={m.value}>
                        {m.label}
                      </option>
                    ))}
                  </select>
                </label>
              ) : null}
              <div className="ax-total-big">
                {money(total - paye)} <span>DH ajoutés au crédit fournisseur</span>
              </div>
            </div>
          </div>
          {fournisseur ? (
            <div className="ax-panel">
              <div className="ax-panel-title">{fournisseur.nom}</div>
              <div className="ax-total-row">
                Crédit actuel <b>{money(fournisseur.solde)} DH</b>
              </div>
              <div className="ax-total-row">
                Après réception <b>{money(Number(fournisseur.solde || 0) + total - paye)} DH</b>
              </div>
              {fournisseur.plafond_credit && Number(fournisseur.solde || 0) + total - paye > Number(fournisseur.plafond_credit) ? (
                <div style={{ marginTop: 8 }}>
                  <span className="ax-badge ax-st-du">Plafond de crédit dépassé ({money(fournisseur.plafond_credit)} DH)</span>
                </div>
              ) : null}
            </div>
          ) : null}
        </aside>
      </div>
    </section>
  )
}
