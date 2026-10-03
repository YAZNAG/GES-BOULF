import { useMemo, useState } from 'react'
import { Trash2, X , Package} from 'lucide-react'

export default function PackModal({ open, mode, initialValues, articles, onClose, onSubmit }) {
  const [nom, setNom] = useState(() => initialValues?.nom ?? '')
  const [description, setDescription] = useState(() => initialValues?.description ?? '')
  const [prixVente, setPrixVente] = useState(() => (initialValues?.prix_vente != null ? String(initialValues.prix_vente) : ''))
  const [actif, setActif] = useState(() => (initialValues?.actif != null ? !!initialValues.actif : true))
  const [items, setItems] = useState(() => {
    const initItems = Array.isArray(initialValues?.items)
      ? initialValues.items.map((it) => ({
          article_id: it.article_id ?? it.article?.id,
          quantite: it.quantite != null ? String(it.quantite) : '1',
        }))
      : []
    return initItems.filter((x) => x.article_id != null)
  })

  const canSubmit = nom.trim() && prixVente !== '' && items.length > 0

  const selectable = useMemo(() => {
    const picked = new Set(items.map((x) => String(x.article_id)))
    return articles.filter((a) => !picked.has(String(a.id)))
  }, [articles, items])

  const itemsView = useMemo(() => {
    const byId = new Map(articles.map((a) => [String(a.id), a]))
    return items.map((it) => ({
      ...it,
      article: byId.get(String(it.article_id)) || null,
    }))
  }, [articles, items])

  if (!open) return null

  function addItem(article) {
    setItems((prev) => [...prev, { article_id: article.id, quantite: '1' }])
  }

  function updateQty(articleId, qty) {
    setItems((prev) => prev.map((x) => (String(x.article_id) === String(articleId) ? { ...x, quantite: qty } : x)))
  }

  function removeItem(articleId) {
    setItems((prev) => prev.filter((x) => String(x.article_id) !== String(articleId)))
  }

  function submit(e) {
    e.preventDefault()
    if (!canSubmit) return
    onSubmit?.({
      nom: nom.trim(),
      description: description.trim() ? description.trim() : null,
      prix_vente: Number(prixVente),
      actif,
      items: items.map((it) => ({ article_id: Number(it.article_id), quantite: Number(it.quantite || 1) })),
    })
  }

  return (
    <div className="modal-overlay" onMouseDown={onClose}>
      <div className="modal packs-modal modal-premium" onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-head-main">
            <div className="modal-icon-bg" style={{ backgroundColor: '#eff6ff', color: '#3b82f6' }}>
              <Package size={20} />
            </div>
            <div>
              <div className="modal-title">{mode === 'edit' ? 'Modifier un pack' : 'Ajouter un pack'}</div>
              <div className="modal-subtitle">Configurez votre offre promotionnelle</div>
            </div>
          </div>
          <button className="modal-x" type="button" onClick={onClose} aria-label="Fermer">
            <X size={20} />
          </button>
        </div>

        <form className="modal-body" onSubmit={submit}>
          <div className="form-grid" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
            <div className="form-group">
              <label className="form-label">Nom du pack</label>
              <input className="form-input" value={nom} onChange={(e) => setNom(e.target.value)} placeholder="Ex: Pack Ramadan" required />
            </div>
            <div className="form-group">
              <label className="form-label">Prix de vente (DH)</label>
              <input className="form-input" value={prixVente} onChange={(e) => setPrixVente(e.target.value)} inputMode="decimal" placeholder="99" required />
            </div>
          </div>

          <div className="form-group">
            <label className="form-label">Description (Optionnel)</label>
            <input className="form-input" value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Détails de l'offre..." />
          </div>

          <label className="users-active-line" style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '13px', fontWeight: '700', cursor: 'pointer' }}>
            <input type="checkbox" checked={actif} onChange={(e) => setActif(e.target.checked)} style={{ width: '18px', height: '18px' }} />
            <span>Le pack est actuellement actif</span>
          </label>

          <div className="packs-items" style={{ marginTop: '10px', borderTop: '1px solid #f1f5f9', paddingTop: '20px' }}>
            <div className="packs-items-head" style={{ marginBottom: '15px', fontSize: '14px', fontWeight: '800' }}>Produits inclus dans le pack</div>

            <div className="form-group" style={{ marginBottom: '20px' }}>
              <label className="form-label">Ajouter un produit</label>
              <div className="select-wrapper">
                <select
                  className="form-input"
                  value=""
                  onChange={(e) => {
                    if (e.target.value) {
                      const a = selectable.find((x) => String(x.id) === String(e.target.value));
                      if (a) addItem(a);
                    }
                  }}
                >
                  <option value="" disabled>-- Sélectionner un article --</option>
                  {selectable.map((a) => (
                    <option key={a.id} value={a.id}>
                      {a.nom} ({a.code_article})
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div className="packs-items-list" style={{ display: 'grid', gap: '10px' }}>
              {itemsView.length === 0 ? <div className="packs-empty" style={{ textAlign: 'center', padding: '20px', background: '#f8fafc', borderRadius: '12px', color: '#94a3b8', fontSize: '13px' }}>Aucun produit ajouté pour le moment.</div> : null}
              {itemsView.map((it) => (
                <div key={it.article_id} className="packs-item" style={{ background: '#fff', border: '1.5px solid #f1f5f9', borderRadius: '14px', padding: '12px 16px', display: 'grid', gridTemplateColumns: '1fr 100px 40px', gap: '15px', alignItems: 'center' }}>
                  <div className="packs-item-main">
                    <div className="packs-item-title" style={{ fontWeight: '800', color: '#0f172a' }}>{it.article?.nom || '—'}</div>
                    <div className="packs-item-sub" style={{ fontSize: '11px', color: '#94a3b8', fontWeight: '600' }}>{it.article?.code_article || ''}</div>
                  </div>
                  <div className="form-group">
                    <input
                      className="form-input"
                      style={{ height: '38px', textAlign: 'center' }}
                      value={it.quantite}
                      onChange={(e) => updateQty(it.article_id, e.target.value)}
                      inputMode="decimal"
                      placeholder="Qté"
                    />
                  </div>
                  <button className="icon-pill icon-pill-danger" type="button" onClick={() => removeItem(it.article_id)} style={{ width: '38px', height: '38px' }}>
                    <Trash2 size={16} />
                  </button>
                </div>
              ))}
            </div>
          </div>

          <div className="modal-foot">
            <button className="btn-ghost" type="button" onClick={onClose}>
              Annuler
            </button>
            <button className="btn-primary" type="submit" disabled={!canSubmit}>
              {mode === 'edit' ? 'Enregistrer les modifications' : 'Créer le pack'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
