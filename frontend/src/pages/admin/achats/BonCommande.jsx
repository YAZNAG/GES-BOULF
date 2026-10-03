import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { Ban, CheckCircle2, PackageCheck, Printer, Save, Trash2, Undo2 } from 'lucide-react'
import { apiFetch } from '../../../lib/api'
import { toast } from '../../../lib/toast'
import { Hero } from '../../../components/catalogue/CatalogueUI'
import ArticleSearch from '../../../components/achats/ArticleSearch'
import ConfirmDialog from '../../../components/ConfirmDialog'
import { STATUTS_BC, articleName, dateFr, json, money, qty, today } from '../../../components/achats/format'
import '../../../styles/catalogue.css'
import '../../../styles/achats.css'

const toLine = (l) => ({
  key: `${l.article_id}-${Math.random()}`,
  article_id: l.article_id,
  article: l.article,
  quantite: String(l.quantite ?? 1),
  quantite_recue: Number(l.quantite_recue || 0),
  prix_unitaire: String(l.prix_unitaire ?? l.article?.prix?.prix_achat ?? 0),
})

/** Bon de commande : création, modification (brouillon), consultation, confirmation, réception. */
export default function BonCommande() {
  const { id } = useParams()
  const navigate = useNavigate()
  const isNew = !id
  const [bc, setBc] = useState(null)
  const [fournisseurs, setFournisseurs] = useState([])
  const [form, setForm] = useState({ fournisseur_id: '', date_commande: today(), date_prevue: '', note: '' })
  const [lines, setLines] = useState([])
  const [busy, setBusy] = useState(false)
  const [confirm, setConfirm] = useState(null)
  const search = useRef(null)

  useEffect(() => {
    apiFetch('/api/fournisseurs?per_page=1000&actif=1').then((r) => setFournisseurs(r.data || [])).catch(() => {})
  }, [])

  useEffect(() => {
    if (isNew) return
    apiFetch(`/api/achats/commandes/${id}`)
      .then((c) => {
        setBc(c)
        setForm({ fournisseur_id: String(c.fournisseur_id || ''), date_commande: c.date_commande || today(), date_prevue: c.date_prevue || '', note: c.note || '' })
        setLines((c.lignes || []).map(toLine))
      })
      .catch((e) => toast({ type: 'error', message: e.message }))
  }, [id, isNew])

  const editable = isNew || bc?.statut === 'brouillon'
  const total = useMemo(() => lines.reduce((s, l) => s + Number(l.quantite || 0) * Number(l.prix_unitaire || 0), 0), [lines])

  function addArticle(a) {
    setLines((ls) => {
      const i = ls.findIndex((l) => l.article_id === a.id)
      if (i >= 0) {
        const next = [...ls]
        next[i] = { ...next[i], quantite: String(Number(next[i].quantite || 0) + 1) }
        return next
      }
      return [...ls, toLine({ article_id: a.id, article: a, quantite: 1, prix_unitaire: Number(a.prix?.prix_achat || 0) })]
    })
  }
  const patch = (key, p) => setLines((ls) => ls.map((l) => (l.key === key ? { ...l, ...p } : l)))

  async function save() {
    if (!form.fournisseur_id) return toast({ type: 'error', message: 'Choisissez un fournisseur.' })
    if (!lines.length) return toast({ type: 'error', message: 'Ajoutez au moins un article.' })
    setBusy(true)
    try {
      const body = {
        ...form,
        date_prevue: form.date_prevue || null,
        lignes: lines.map((l) => ({ article_id: l.article_id, quantite: Number(l.quantite), prix_unitaire: Number(l.prix_unitaire || 0) })),
      }
      const c = await apiFetch(isNew ? '/api/achats/commandes' : `/api/achats/commandes/${id}`, json(isNew ? 'POST' : 'PUT', body))
      toast({ type: 'success', message: `Bon ${c.numero} enregistré.` })
      if (isNew) navigate(`/admin/achats/commandes/${c.id}`, { replace: true })
      else setBc((b) => ({ ...b, ...c }))
    } catch (e) {
      toast({ type: 'error', message: e.message })
    } finally {
      setBusy(false)
    }
  }

  async function statut(s) {
    setConfirm(null)
    setBusy(true)
    try {
      const c = await apiFetch(`/api/achats/commandes/${id}/statut`, json('POST', { statut: s }))
      setBc((b) => ({ ...b, statut: c.statut }))
      toast({ type: 'success', message: `Bon de commande ${STATUTS_BC[c.statut].toLowerCase()}.` })
    } catch (e) {
      toast({ type: 'error', message: e.message })
    } finally {
      setBusy(false)
    }
  }

  async function remove() {
    setConfirm(null)
    try {
      await apiFetch(`/api/achats/commandes/${id}`, { method: 'DELETE' })
      toast({ type: 'success', message: 'Brouillon supprimé.' })
      navigate('/admin/achats/commandes')
    } catch (e) {
      toast({ type: 'error', message: e.message })
    }
  }

  const fournisseur = fournisseurs.find((f) => String(f.id) === String(form.fournisseur_id)) || bc?.fournisseur
  const recevable = bc && ['confirmee', 'partielle'].includes(bc.statut)

  return (
    <section className="cx">
      <Hero
        crumbs={[{ label: 'Achats' }, { label: 'Bons de commande', to: '/admin/achats/commandes' }, { label: isNew ? 'Nouveau' : bc?.numero || '…' }]}
        title={isNew ? 'Nouveau bon de commande' : bc?.numero || 'Bon de commande'}
        titleAr="طلبية شراء"
        subtitle={fournisseur ? `Fournisseur : ${fournisseur.nom}` : 'Choisissez le fournisseur puis scannez ou recherchez les articles.'}
        stats={[
          { label: 'Statut', value: bc ? STATUTS_BC[bc.statut] : 'Brouillon' },
          { label: 'Articles', value: String(lines.length) },
          { label: 'Total (DH)', value: money(total) },
        ]}
        actions={
          <div className="ax-noprint" style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {!isNew ? (
              <button className="cx-btn cx-btn-ghost-light" type="button" onClick={() => window.print()}>
                <Printer size={16} /> Imprimer
              </button>
            ) : null}
            {bc?.statut === 'brouillon' ? (
              <button className="cx-btn cx-btn-ghost-light" type="button" disabled={busy} onClick={() => setConfirm('confirmee')}>
                <CheckCircle2 size={16} /> Confirmer
              </button>
            ) : null}
            {recevable ? (
              <button className="cx-btn cx-btn-primary" type="button" onClick={() => navigate(`/admin/achats/receptions/nouvelle?commande=${bc.id}`)}>
                <PackageCheck size={16} /> Réceptionner
              </button>
            ) : null}
            {editable ? (
              <button className="cx-btn cx-btn-primary" type="button" disabled={busy} onClick={save}>
                <Save size={16} /> {busy ? 'Enregistrement…' : 'Enregistrer'}
              </button>
            ) : null}
          </div>
        }
      />

      <div className="ax-layout">
        <div>
          <div className="ax-panel">
            <div className="ax-form">
              <label className="ax-field">
                Fournisseur *
                <select value={form.fournisseur_id} disabled={!editable} onChange={(e) => setForm({ ...form, fournisseur_id: e.target.value })}>
                  <option value="">Choisir…</option>
                  {fournisseurs.map((f) => (
                    <option key={f.id} value={f.id}>
                      {f.nom}
                    </option>
                  ))}
                </select>
              </label>
              <label className="ax-field">
                Date de commande
                <input type="date" value={form.date_commande} disabled={!editable} onChange={(e) => setForm({ ...form, date_commande: e.target.value })} />
              </label>
              <label className="ax-field">
                Livraison prévue
                <input type="date" value={form.date_prevue} disabled={!editable} onChange={(e) => setForm({ ...form, date_prevue: e.target.value })} />
              </label>
              <label className="ax-field ax-field-wide">
                Note
                <input value={form.note} disabled={!editable} onChange={(e) => setForm({ ...form, note: e.target.value })} placeholder="Conditions, contact livreur…" />
              </label>
            </div>
          </div>

          <div className="ax-panel">
            <div className="ax-panel-title">
              Articles commandés
              {editable ? <span className="ax-muted">Scannez : l’article est ajouté (ou sa quantité augmente).</span> : null}
            </div>
            {editable ? (
              <div className="ax-noprint" style={{ marginBottom: 12 }}>
                <ArticleSearch ref={search} onPick={addArticle} />
              </div>
            ) : null}
            <div className="ax-table-wrap">
              <table className="ax-table">
                <thead>
                  <tr>
                    <th>Article</th>
                    <th className="ax-num">Stock</th>
                    <th className="ax-num">Quantité</th>
                    <th className="ax-num">Prix d’achat (DH)</th>
                    <th className="ax-num">Total</th>
                    {!editable ? <th>Reçu</th> : <th className="ax-noprint" />}
                  </tr>
                </thead>
                <tbody>
                  {!lines.length ? (
                    <tr className="ax-empty-row">
                      <td colSpan={6}>Aucun article. Scannez un code-barres ou recherchez un produit.</td>
                    </tr>
                  ) : null}
                  {lines.map((l) => {
                    const pct = Number(l.quantite) > 0 ? Math.min(100, (l.quantite_recue / Number(l.quantite)) * 100) : 0
                    return (
                      <tr key={l.key}>
                        <td>
                          <div className="ax-prod">
                            {l.article?.image ? <img src={l.article.image} alt="" /> : <span className="ax-thumb" />}
                            <div>
                              <div className="ax-prod-name">{articleName(l.article)}</div>
                              <div className="ax-muted">{l.article?.code_article}</div>
                            </div>
                          </div>
                        </td>
                        <td className="ax-num ax-muted">{qty(l.article?.stock?.quantite)}</td>
                        <td className="ax-num">
                          {editable ? (
                            <input className="ax-in" value={l.quantite} inputMode="decimal" onChange={(e) => patch(l.key, { quantite: e.target.value.replace(',', '.') })} />
                          ) : (
                            qty(l.quantite)
                          )}
                        </td>
                        <td className="ax-num">
                          {editable ? (
                            <input className="ax-in" value={l.prix_unitaire} inputMode="decimal" onChange={(e) => patch(l.key, { prix_unitaire: e.target.value.replace(',', '.') })} />
                          ) : (
                            money(l.prix_unitaire)
                          )}
                        </td>
                        <td className="ax-num ax-strong">{money(Number(l.quantite || 0) * Number(l.prix_unitaire || 0))}</td>
                        {!editable ? (
                          <td>
                            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                              <div className="ax-progress">
                                <i style={{ width: `${pct}%` }} />
                              </div>
                              <span className="ax-muted">
                                {qty(l.quantite_recue)}/{qty(l.quantite)}
                              </span>
                            </div>
                          </td>
                        ) : (
                          <td className="ax-noprint">
                            <button className="cx-icon-btn cx-icon-btn-danger" type="button" onClick={() => setLines((ls) => ls.filter((x) => x.key !== l.key))} title="Retirer">
                              <Trash2 size={15} />
                            </button>
                          </td>
                        )}
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
            <div className="ax-panel-title">Récapitulatif</div>
            <div className="ax-totals">
              <div className="ax-total-row">
                Articles <b>{lines.length}</b>
              </div>
              <div className="ax-total-row">
                Quantité totale <b>{qty(lines.reduce((s, l) => s + Number(l.quantite || 0), 0))}</b>
              </div>
              <div className="ax-total-big">
                {money(total)} <span>DH</span>
              </div>
            </div>
          </div>
          {fournisseur ? (
            <div className="ax-panel">
              <div className="ax-panel-title">Fournisseur</div>
              <div className="ax-strong">{fournisseur.nom}</div>
              <div className="ax-muted">{[fournisseur.telephone, fournisseur.ville].filter(Boolean).join(' · ') || '—'}</div>
              {Number(fournisseur.solde) > 0 ? (
                <div style={{ marginTop: 8 }}>
                  <span className="ax-badge ax-st-du">Crédit dû : {money(fournisseur.solde)} DH</span>
                </div>
              ) : null}
            </div>
          ) : null}
          {bc?.receptions?.length ? (
            <div className="ax-panel">
              <div className="ax-panel-title">Réceptions</div>
              {bc.receptions.map((r) => (
                <div key={r.id} className="ax-total-row" style={{ cursor: 'pointer' }} onClick={() => navigate(`/admin/achats/receptions/${r.id}`)}>
                  {r.numero} · {dateFr(r.date_reception)} <b>{money(r.total)}</b>
                </div>
              ))}
            </div>
          ) : null}
          {bc && ['brouillon', 'confirmee'].includes(bc.statut) ? (
            <div className="ax-panel ax-noprint" style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {bc.statut === 'confirmee' && !bc.receptions?.length ? (
                <button className="cx-btn" type="button" onClick={() => statut('brouillon')}>
                  <Undo2 size={16} /> Repasser en brouillon
                </button>
              ) : null}
              <button className="cx-btn" type="button" onClick={() => setConfirm('annulee')}>
                <Ban size={16} /> Annuler le bon
              </button>
              {bc.statut === 'brouillon' ? (
                <button className="cx-btn" type="button" style={{ color: '#dc2626' }} onClick={() => setConfirm('supprimer')}>
                  <Trash2 size={16} /> Supprimer le brouillon
                </button>
              ) : null}
            </div>
          ) : null}
        </aside>
      </div>

      <ConfirmDialog
        open={!!confirm}
        title={confirm === 'confirmee' ? 'Confirmer le bon de commande' : confirm === 'annulee' ? 'Annuler le bon de commande' : 'Supprimer le brouillon'}
        message={
          confirm === 'confirmee'
            ? 'Le bon ne sera plus modifiable et pourra être réceptionné.'
            : confirm === 'annulee'
              ? 'Le bon sera marqué annulé. Cette action ne touche pas au stock.'
              : 'Ce brouillon sera définitivement supprimé.'
        }
        confirmLabel={confirm === 'confirmee' ? 'Confirmer' : confirm === 'annulee' ? 'Annuler le bon' : 'Supprimer'}
        onConfirm={() => (confirm === 'supprimer' ? remove() : statut(confirm))}
        onCancel={() => setConfirm(null)}
      />
    </section>
  )
}
