import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { PackageCheck, Search, SlidersHorizontal, X } from 'lucide-react'
import { apiFetch } from '../../lib/api'
import { toast } from '../../lib/toast'
import { Hero } from '../../components/catalogue/CatalogueUI'
import { fmtInt, listOf } from '../../components/catalogue/format'
import { articleName, json, money, qty } from '../../components/achats/format'
import '../../styles/catalogue.css'
import '../../styles/achats.css'

const STATUTS = [
  ['', 'Tous'],
  ['en_stock', 'En stock', 'en_stock'],
  ['sous_seuil', 'Sous le seuil', 'sous_seuil'],
  ['rupture', 'En rupture', 'rupture'],
]

function AjusterModal({ item, onClose, onDone }) {
  const [f, setF] = useState({ mode: 'inventaire', quantite: String(Number(item.quantite)), motif: 'ajustement', note: '', seuil_min: String(Number(item.seuil_min)) })
  const [busy, setBusy] = useState(false)
  const avant = Number(item.quantite)
  const n = Number(String(f.quantite).replace(',', '.')) || 0
  const apres = f.mode === 'inventaire' ? n : f.mode === 'plus' ? avant + n : avant - n

  async function submit(e) {
    e.preventDefault()
    setBusy(true)
    try {
      await apiFetch(
        '/api/stock/ajuster',
        json('POST', { article_id: item.article_id, mode: f.mode, quantite: n, motif: f.motif, note: f.note || null, seuil_min: Number(f.seuil_min) || 0 })
      )
      toast({ type: 'success', message: 'Stock mis à jour.' })
      onDone()
    } catch (err) {
      toast({ type: 'error', message: err.message })
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="cx-modal-back" onMouseDown={onClose}>
      <div className="cx-modal" role="dialog" aria-modal="true" onMouseDown={(e) => e.stopPropagation()}>
        <div className="cx-modal-head">
          <div className="cx-modal-title">Ajuster : {articleName(item.article)}</div>
          <button className="cx-icon-btn" type="button" onClick={onClose} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>
        <form className="cx-modal-body" onSubmit={submit}>
          <div className="cx-chips" style={{ marginBottom: 0 }}>
            {[
              ['inventaire', 'Inventaire (quantité comptée)'],
              ['plus', 'Ajouter'],
              ['moins', 'Retirer'],
            ].map(([k, l]) => (
              <button key={k} type="button" className={`cx-chip ${f.mode === k ? 'on' : ''}`} onClick={() => setF({ ...f, mode: k, quantite: k === 'inventaire' ? String(avant) : '' })}>
                {l}
              </button>
            ))}
          </div>
          <div className="cx-two">
            <label className="cx-field">
              {f.mode === 'inventaire' ? 'Quantité comptée' : 'Quantité'}
              <input value={f.quantite} autoFocus inputMode="decimal" onChange={(e) => setF({ ...f, quantite: e.target.value })} />
            </label>
            <label className="cx-field">
              Seuil d’alerte
              <input value={f.seuil_min} inputMode="decimal" onChange={(e) => setF({ ...f, seuil_min: e.target.value })} />
            </label>
            {f.mode === 'moins' ? (
              <label className="cx-field">
                Motif
                <select value={f.motif} onChange={(e) => setF({ ...f, motif: e.target.value })}>
                  <option value="ajustement">Ajustement</option>
                  <option value="perte">Perte / casse</option>
                  <option value="don">Don</option>
                  <option value="retour">Retour fournisseur</option>
                </select>
              </label>
            ) : null}
            <label className="cx-field">
              Note
              <input value={f.note} onChange={(e) => setF({ ...f, note: e.target.value })} />
            </label>
          </div>
          <div className="cx-note" style={{ background: '#f8fafc', borderColor: '#e2e8f0', color: '#334155' }}>
            Stock : <b>&nbsp;{qty(avant)}</b>&nbsp;→&nbsp;<b style={{ color: apres < 0 ? '#dc2626' : '#16a34a' }}>{qty(apres)}</b>&nbsp;{item.article?.unite}
          </div>
          <div className="cx-modal-foot">
            <button className="cx-btn" type="button" onClick={onClose}>
              Annuler
            </button>
            <button className="cx-btn cx-btn-primary" type="submit" disabled={busy || apres < 0}>
              {busy ? 'Enregistrement…' : 'Valider'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

/** Articles en stock : quantités, seuils, valeur du stock, ajustements et inventaire. */
export default function Stock() {
  const navigate = useNavigate()
  const [q, setQ] = useState('')
  const [statut, setStatut] = useState('en_stock')
  const [famille, setFamille] = useState('')
  const [sort, setSort] = useState('nom')
  const [page, setPage] = useState(1)
  const [res, setRes] = useState(null)
  const [familles, setFamilles] = useState([])
  const [ajuster, setAjuster] = useState(null)

  useEffect(() => {
    apiFetch('/api/familles?per_page=200').then((r) => setFamilles(listOf(r))).catch(() => {})
  }, [])

  const load = useCallback(async () => {
    const qs = new URLSearchParams({ page: String(page), per_page: '40', with_stats: '1', sort })
    if (q.trim()) qs.set('q', q.trim())
    if (statut) qs.set('statut', statut)
    if (famille) qs.set('famille_id', famille)
    setRes(await apiFetch(`/api/stock?${qs}`))
  }, [page, q, statut, famille, sort])

  useEffect(() => {
    const t = setTimeout(() => load().catch((e) => toast({ type: 'error', message: e.message })), q ? 300 : 0)
    return () => clearTimeout(t)
  }, [load, q])

  const s = res?.stats

  return (
    <section className="cx">
      <Hero
        crumbs={[{ label: 'Stock' }]}
        title="Articles en stock"
        titleAr="المخزون"
        subtitle="Quantités disponibles, alertes de seuil et valeur de la marchandise en magasin."
        stats={
          s
            ? [
                { label: 'Articles en stock', value: fmtInt(s.en_stock) },
                { label: 'Sous le seuil', value: fmtInt(s.sous_seuil), warn: s.sous_seuil > 0 },
                { label: 'En rupture (actifs)', value: fmtInt(s.rupture), warn: s.rupture > 0 },
                { label: 'Valeur d’achat (DH)', value: money(s.valeur_achat) },
                { label: 'Valeur de vente (DH)', value: money(s.valeur_vente) },
              ]
            : []
        }
        actions={
          <button className="cx-btn cx-btn-primary" type="button" onClick={() => navigate('/admin/achats/receptions/nouvelle')}>
            <PackageCheck size={16} /> Entrée de stock
          </button>
        }
      />

      <div className="cx-toolbar">
        <label className="cx-search">
          <Search size={18} color="#94a3b8" />
          <input value={q} onChange={(e) => (setQ(e.target.value), setPage(1))} placeholder="Produit ou code-barres…" />
        </label>
        <select className="cx-select" value={famille} onChange={(e) => (setFamille(e.target.value), setPage(1))}>
          <option value="">Toutes les familles</option>
          {familles.map((x) => (
            <option key={x.id} value={x.id}>
              {x.nom_fr}
            </option>
          ))}
        </select>
        <select className="cx-select" value={sort} onChange={(e) => (setSort(e.target.value), setPage(1))}>
          <option value="nom">Trier : nom</option>
          <option value="quantite_asc">Quantité croissante</option>
          <option value="quantite_desc">Quantité décroissante</option>
          <option value="valeur">Valeur du stock</option>
        </select>
      </div>
      <div className="cx-chips">
        {STATUTS.map(([v, l, k]) => (
          <button key={v || 'all'} className={`cx-chip ${statut === v ? 'on' : ''}`} type="button" onClick={() => (setStatut(v), setPage(1))}>
            {l}
            {s && k ? <span className="cx-chip-count">{fmtInt(s[k])}</span> : null}
          </button>
        ))}
      </div>

      <div className="ax-table-wrap">
        <table className="ax-table">
          <thead>
            <tr>
              <th>Article</th>
              <th>Catégorie</th>
              <th className="ax-num">Quantité</th>
              <th className="ax-num">Seuil</th>
              <th className="ax-num">Prix d’achat</th>
              <th className="ax-num">Valeur (DH)</th>
              <th>État</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {!res ? (
              <tr className="ax-empty-row">
                <td colSpan={8}>Chargement…</td>
              </tr>
            ) : null}
            {res && !res.data?.length ? (
              <tr className="ax-empty-row">
                <td colSpan={8}>Aucun article pour ce filtre.</td>
              </tr>
            ) : null}
            {res?.data?.map((r) => {
              const quantite = Number(r.quantite)
              const etat = quantite <= 0 ? ['annulee', 'Rupture'] : quantite <= Number(r.seuil_min) ? ['partielle', 'Sous le seuil'] : ['recue', 'OK']
              return (
                <tr key={r.id} className="ax-click" onClick={() => navigate(`/admin/produits/${r.article_id}`)}>
                  <td>
                    <div className="ax-prod">
                      {r.article?.image ? <img src={r.article.image} alt="" loading="lazy" /> : <span className="ax-thumb" />}
                      <div>
                        <div className="ax-prod-name">{articleName(r.article)}</div>
                        <div className="ax-muted">
                          {r.article?.marque?.nom ? `${r.article.marque.nom} · ` : ''}
                          {r.article?.code_article}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="ax-muted">{r.article?.sous_categorie?.name_fr || r.article?.sous_categorie?.nom}</td>
                  <td className="ax-num ax-strong">
                    {qty(quantite)} <span className="ax-muted">{r.article?.unite}</span>
                  </td>
                  <td className="ax-num">{qty(r.seuil_min)}</td>
                  <td className="ax-num">{money(r.prix_achat)}</td>
                  <td className="ax-num">{money(r.valeur_achat)}</td>
                  <td>
                    <span className={`ax-badge ax-st-${etat[0]}`}>{etat[1]}</span>
                  </td>
                  <td onClick={(e) => e.stopPropagation()}>
                    <button className="cx-btn" type="button" style={{ height: 32 }} onClick={() => setAjuster(r)}>
                      <SlidersHorizontal size={14} /> Ajuster
                    </button>
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
            {res.from}–{res.to} sur {fmtInt(res.total)}
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

      {ajuster ? (
        <AjusterModal
          item={ajuster}
          onClose={() => setAjuster(null)}
          onDone={() => {
            setAjuster(null)
            load()
          }}
        />
      ) : null}
    </section>
  )
}
