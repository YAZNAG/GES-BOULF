import { useEffect, useMemo, useState } from 'react'
import { LayoutGrid, List, Minus, Pencil, Plus, Search, X, Download } from 'lucide-react'
import { useOutletContext } from 'react-router-dom'
import { apiFetch } from '../../lib/api'
import { CSVLink } from 'react-csv'
import Alert from '../../components/Alert'
import '../../styles/stock.css'

export default function Stock() {
  const outlet = useOutletContext() || {}
  const search = (outlet.search || '').toString()
  const setSearch = typeof outlet.setSearch === 'function' ? outlet.setSearch : () => {}

  const [articles, setArticles] = useState([])
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const [filter, setFilter] = useState('all')

  const [open, setOpen] = useState(false)
  const [adjustOpen, setAdjustOpen] = useState(false)
  const [editing, setEditing] = useState(null)
  const [creating, setCreating] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [success, setSuccess] = useState('')
  const [view, setView] = useState('list')

  const [form, setForm] = useState({
    article_id: '',
    quantite: '',
    seuil_min: '',
  })

  const [adjust, setAdjust] = useState({
    article_id: '',
    sens: 'plus',
    motif: 'ajustement',
    quantite: '',
    note: '',
  })

  async function loadAll() {
    setLoading(true)
    setError('')
    try {
      const [articlesRes, stockRes] = await Promise.all([
        apiFetch('/api/articles?per_page=1000'),
        apiFetch('/api/stock?per_page=1000'),
      ])
      const a = Array.isArray(articlesRes?.data) ? articlesRes.data : articlesRes?.data?.data || []
      const s = Array.isArray(stockRes?.data) ? stockRes.data : stockRes?.data?.data || []
      setArticles(a)
      setItems(s)
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadAll()
  }, [])

  const stockByArticleId = useMemo(() => new Map(items.map((it) => [String(it.article_id), it])), [items])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return items.filter((s) => {
      const articleNom = (s?.article?.nom || '').toString().toLowerCase()
      const code = (s?.article?.code_article || '').toString().toLowerCase()
      const okQuery = !q ? true : articleNom.includes(q) || code.includes(q)
      const qty = Number(s?.quantite ?? 0)
      const seuil = Number(s?.seuil_min ?? 0)
      const low = qty <= seuil
      const okFilter = filter === 'all' ? true : low
      return okQuery && okFilter
    })
  }, [items, search, filter])

  function openCreate() {
    setSuccess('')
    setError('')
    setAdjust({
      article_id: '',
      sens: 'plus',
      motif: 'ajustement',
      quantite: '',
      note: '',
    })
    setAdjustOpen(true)
  }

  function openEdit(row) {
    setCreating(false)
    setEditing(row)
    setForm({
      article_id: String(row?.article_id || ''),
      quantite: Number(row?.quantite ?? 0),
      seuil_min: Number(row?.seuil_min ?? 0),
    })
    setOpen(true)
  }

  async function submit(e) {
    e.preventDefault()
    setError('')
    setSuccess('')
    setSubmitting(true)
    try {
      const payload = {
        article_id: Number(form.article_id),
        quantite: Number(form.quantite),
        seuil_min: Number(form.seuil_min),
      }

      if (creating) {
        await apiFetch('/api/stock', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        })
      } else if (editing?.id) {
        await apiFetch(`/api/stock/${editing.id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ quantite: payload.quantite, seuil_min: payload.seuil_min }),
        })
      }

      setOpen(false)
      setSuccess('Stock mis à jour.')
      await loadAll()
    } catch (e2) {
      setError(e2?.message || 'Erreur')
    } finally {
      setSubmitting(false)
    }
  }

  async function submitAdjust(e) {
    e.preventDefault()
    setError('')
    setSuccess('')

    const articleId = Number(adjust.article_id)
    const qty = Number(adjust.quantite)
    if (!Number.isFinite(articleId) || articleId <= 0) {
      setError('Sélectionne un article.')
      return
    }
    if (!Number.isFinite(qty) || qty <= 0) {
      setError('Quantité invalide.')
      return
    }

    const sens = adjust.sens === 'moins' ? 'moins' : 'plus'
    const type_mouvement = sens === 'moins' ? 'sortie' : 'entree'
    const motif = (adjust.motif || 'ajustement').toString()

    setSubmitting(true)
    try {
      let stock = stockByArticleId.get(String(articleId))
      if (!stock) {
        stock = await apiFetch('/api/stock', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ article_id: articleId, quantite: 0, seuil_min: 0 }),
        })
      }

      const currentQty = Number(stock?.quantite ?? 0)
      const nextQty = sens === 'moins' ? currentQty - qty : currentQty + qty
      if (nextQty < 0) {
        throw new Error('Stock insuffisant.')
      }

      await apiFetch(`/api/stock/${stock.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ quantite: nextQty }),
      })

      await apiFetch('/api/mouvements_stock', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          article_id: articleId,
          type_mouvement,
          motif,
          quantite: qty,
          note: adjust.note || null,
          reference_type: 'stock',
          reference_id: null,
        }),
      })

      setAdjustOpen(false)
      setSuccess('Mouvement enregistré.')
      await loadAll()
    } catch (e2) {
      setError(e2?.message || 'Erreur')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <section className="content">
      <div className="page-head">
        <div>
          <div className="page-title">Stock</div>
          <div className="page-subtitle">Gestion du stock</div>
        </div>
        <button className="primary primary-pill" type="button" onClick={openCreate}>
          <Plus size={16} />
          Ajouter
        </button>
      </div>

      <div className="toolbar">
        <div className="toolbar-left">
          <div className="tool-search">
            <Search size={16} color="#94a3b8" />
            <input
              className="tool-search-input"
              placeholder="Rechercher (nom ou code)…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <select className="tool-select" value={filter} onChange={(e) => setFilter(e.target.value)}>
            <option value="all">Tous</option>
            <option value="low">Stock bas</option>
          </select>
        </div>
        <div className="toolbar-right">
          <div className="view-toggles" style={{ display: 'flex', gap: '8px', marginRight: '12px' }}>
            <button
              className={`view-btn ${view === 'grid' ? 'view-btn-active' : ''}`}
              type="button"
              onClick={() => setView('grid')}
              aria-label="Vue grille"
            >
              <LayoutGrid size={16} />
            </button>
            <button
              className={`view-btn ${view === 'list' ? 'view-btn-active' : ''}`}
              type="button"
              onClick={() => setView('list')}
              aria-label="Vue liste"
            >
              <List size={16} />
            </button>
          </div>
          <button className="btn-secondary" type="button">
            <Download size={16} />
            <CSVLink data={filtered} filename="stock.csv" style={{ color: 'inherit', textDecoration: 'none' }}>
              Exporter
            </CSVLink>
          </button>
        </div>
      </div>

      <Alert type="error" message={error} />
      <Alert type="success" message={success} />

      <div className="stock-card">
        <div className="stock-card-head">
          <div className="stock-card-title">Liste du stock ({filtered.length})</div>
        </div>

      {loading ? (
        <div className="stock-empty">Loading…</div>
      ) : view === 'list' ? (
        <div className="stock-card">
          <div className="stock-card-head">
            <div className="stock-card-title">Liste du stock ({filtered.length})</div>
          </div>
          <div className="stock-table-wrap">
            <table className="stock-table">
              <thead>
                <tr>
                  <th>Produit</th>
                  <th>Quantité</th>
                  <th>Seuil min</th>
                  <th>État</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((s) => {
                  const qty = Number(s?.quantite ?? 0)
                  const seuil = Number(s?.seuil_min ?? 0)
                  const low = qty <= seuil
                  const label = low ? 'Stock bas' : 'OK'
                  const badgeCls = low ? 'status-badge status-annule' : 'status-badge status-livre'
                  const code = s?.article?.code_article ? `(${s.article.code_article}) ` : ''
                  return (
                    <tr key={s.id}>
                      <td className="fw-500">
                        {code}
                        {s?.article?.nom || '—'}
                      </td>
                      <td>{qty} {s?.article?.unite || ''}</td>
                      <td>{seuil}</td>
                      <td>
                        <span className={badgeCls}>{label}</span>
                      </td>
                      <td>
                        <div className="stock-actions">
                          <button className="icon-pill" type="button" onClick={() => openEdit(s)} aria-label="Modifier">
                            <Pencil size={18} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })}
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan="5" className="stock-empty-cell">
                      Aucun stock
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        <div className="stock-grid">
          {filtered.map((s) => {
            const qty = Number(s?.quantite ?? 0)
            const seuil = Number(s?.seuil_min ?? 0)
            const low = qty <= seuil
            const label = low ? 'Stock bas' : 'Stock OK'
            const badgeCls = low ? 'status-badge status-annule' : 'status-badge status-livre'
            return (
              <div key={s.id} className="stock-item-card">
                
                <div className="stock-item-img">
                   <img src={s?.article?.image || '/imagelogin.png'} alt={s?.article?.nom} />
                </div>
                <div className="stock-item-info">
                  <div className="stock-item-name">{s?.article?.nom || '—'}</div>
                  <div className="stock-item-code">{s?.article?.code_article || 'N/A'}</div>
                  <div className="stock-item-stats">
                    <div className="stat-box">
                      <div className="stat-label">Quantité</div>
                      <div className={`stat-val ${low ? 'val-danger' : 'val-success'}`}>{qty} <small>{s?.article?.unite || ''}</small></div>
                    </div>
                    <div className="stat-box">
                      <div className="stat-label">Seuil Min</div>
                      <div className="stat-val">{seuil}</div>
                    </div>
                  </div>
                </div>
                <div className="stock-item-foot">
                   <button className="btn-adjust" onClick={() => openEdit(s)}>
                      <Pencil size={14} />
                      Gérer le stock
                   </button>
                </div>
              </div>
            )
          })}
          {filtered.length === 0 ? <div className="stock-empty">Aucun stock trouvé</div> : null}
        </div>
      )}
      </div>

      {open ? (
        <div className="modal-overlay" onClick={() => setOpen(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <div className="modal-title">{creating ? 'Ajouter un stock' : 'Modifier le stock'}</div>
              <button className="modal-x" type="button" onClick={() => setOpen(false)} aria-label="Fermer">
                <X size={18} />
              </button>
            </div>
            <form className="modal-body" onSubmit={submit}>
              <label className="form-label">
                Article
                <select
                  className="form-select"
                  value={form.article_id}
                  onChange={(e) => setForm((p) => ({ ...p, article_id: e.target.value }))}
                  disabled={!creating}
                  required
                >
                  <option value="">Sélectionner un article</option>
                  {articles.map((a) => (
                    <option key={a.id} value={a.id}>
                      {a.code_article ? `${a.code_article} — ` : ''}
                      {a.nom}
                    </option>
                  ))}
                </select>
              </label>

              <div className="form-grid">
                <label className="form-label">
                  Quantité
                  <input
                    className="form-input"
                    type="number"
                    step="0.01"
                    value={form.quantite}
                    onChange={(e) => setForm((p) => ({ ...p, quantite: e.target.value }))}
                    required
                  />
                </label>

                <label className="form-label">
                  Seuil minimum
                  <input
                    className="form-input"
                    type="number"
                    step="0.01"
                    value={form.seuil_min}
                    onChange={(e) => setForm((p) => ({ ...p, seuil_min: e.target.value }))}
                    required
                  />
                </label>
              </div>

              <div className="modal-foot">
                <button className="btn-ghost" type="button" onClick={() => setOpen(false)}>
                  Annuler
                </button>
                <button className="btn-primary" type="submit" disabled={submitting}>
                  Enregistrer
                </button>
              </div>
            </form>
          </div>
        </div>
        
      ) : null}

      {adjustOpen ? (
        <div className="modal-overlay" onClick={() => setAdjustOpen(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <div className="modal-title">Ajouter du stock</div>
              <button className="modal-x" type="button" onClick={() => setAdjustOpen(false)} aria-label="Fermer">
                <X size={18} />
              </button>
            </div>
            <form className="modal-body" onSubmit={submitAdjust}>
              <label className="form-label">
                Article
                <select
                  className="form-select"
                  value={adjust.article_id}
                  onChange={(e) => setAdjust((p) => ({ ...p, article_id: e.target.value }))}
                  required
                >
                  <option value="">Sélectionner un article</option>
                  {articles.map((a) => (
                    <option key={a.id} value={a.id}>
                      {a.code_article ? `${a.code_article} — ` : ''}
                      {a.nom}
                    </option>
                  ))}
                </select>
              </label>

              <div className="form-grid">
                <label className="form-label">
                  Quantité
                  <input
                    className="form-input"
                    type="number"
                    step="0.01"
                    value={adjust.quantite}
                    onChange={(e) => setAdjust((p) => ({ ...p, quantite: e.target.value }))}
                    required
                    disabled={submitting}
                  />
                </label>

                <label className="form-label">
                  Note (optionnel)
                  <input
                    className="form-input"
                    value={adjust.note}
                    onChange={(e) => setAdjust((p) => ({ ...p, note: e.target.value }))}
                    disabled={submitting}
                  />
                </label>
              </div>

              <div className="modal-foot">
                <button className="btn-ghost" type="button" onClick={() => setAdjustOpen(false)} disabled={submitting}>
                  Annuler
                </button>
                <button className="btn-primary" type="submit" disabled={submitting}>
                  {submitting ? 'Enregistrement…' : 'Valider'}
                </button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </section>
  )
}
