import { useEffect, useMemo, useState } from 'react'
import { Tag, X } from 'lucide-react'

export function PromoModal({ open, onClose, onSubmit, initial, targets }) {
  const [name, setName] = useState(() => initial?.name || '')
  const [code, setCode] = useState(() => initial?.code_promo || '')
  const [type, setType] = useState(() => initial?.type || 'pourcentage')
  const [value, setValue] = useState(() => (initial?.value != null ? String(initial.value) : ''))
  const [startDate, setStartDate] = useState(() => initial?.start_date?.split('T')[0] || '')
  const [endDate, setEndDate] = useState(() => initial?.end_date?.split('T')[0] || '')
  const [minPanier, setMinPanier] = useState(() => (initial?.panier_min != null ? String(initial.panier_min) : ''))
  const [targetType, setTargetType] = useState(() => initial?.target_type || 'category')
  const [targetId, setTargetId] = useState(() => (initial?.target_id != null ? String(initial.target_id) : ''))

  const canSubmit = useMemo(() => {
    return name.trim() && value !== '' && startDate && endDate && targetType && targetId
  }, [name, value, startDate, endDate, targetType, targetId])

  useEffect(() => {
    if (!open) return
    function onKeyDown(e) {
      if (e.key === 'Escape') onClose?.()
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [open, onClose])

  const targetList = useMemo(() => {
    const t = targets || {}
    const list = t[targetType] || []
    return Array.isArray(list) ? list : []
  }, [targets, targetType])

  const effectiveTargetId = useMemo(() => {
    if (!targetList.length) return ''
    if (targetId && targetList.some((t) => String(t.id) === String(targetId))) return String(targetId)
    return String(targetList[0].id)
  }, [targetList, targetId])

  if (!open) return null

  function submit(e) {
    e.preventDefault()
    if (!canSubmit) return
    onSubmit?.({
      id: initial?.id,
      name: name.trim(),
      code_promo: code.trim() || null,
      type,
      value: Number(value),
      panier_min: minPanier === '' ? 0 : Number(minPanier),
      start_date: startDate,
      end_date: endDate,
      target_type: targetType,
      target_id: Number(effectiveTargetId),
      is_active: true,
    })
  }

  const title = initial ? 'Modifier la promotion' : 'Créer une nouvelle promotion'

  return (
    <div className="modal-overlay" onMouseDown={onClose}>
      <div className="promo-modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-title">{title}</div>
          <button className="modal-x" type="button" onClick={onClose} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>

        <form className="promo-form" onSubmit={submit}>
          <div className="promo-form-left">
            <label className="form-label">
              Nom de la promotion
              <input className="form-input" value={name} onChange={(e) => setName(e.target.value)} placeholder="Ex: Promotion Printemps" />
            </label>

            <label className="form-label">
              Code promo
              <input className="form-input form-input-muted" value={code} onChange={(e) => setCode(e.target.value)} placeholder="Ex: SPRING25" />
            </label>

            <label className="form-label">
              Type de promotion
              <div className="select-wrap">
                <select className="form-select" value={type} onChange={(e) => setType(e.target.value)}>
                  <option value="pourcentage">Pourcentage</option>
                  <option value="montant_fixe">Montant fixe</option>
                </select>
              </div>
            </label>

            <label className="form-label">
              {type === 'pourcentage' ? 'Pourcentage (%)' : 'Montant (DH)'}
              <input className="form-input form-input-muted" inputMode="decimal" value={value} onChange={(e) => setValue(e.target.value)} placeholder="25" />
            </label>

            <div className="form-grid">
              <label className="form-label">
                Date début
                <input className="form-input form-input-muted" type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} />
              </label>
              <label className="form-label">
                Date fin
                <input className="form-input form-input-muted" type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} />
              </label>
            </div>

            <label className="form-label">
              Panier minimum (DH)
              <input className="form-input form-input-muted" inputMode="decimal" value={minPanier} onChange={(e) => setMinPanier(e.target.value)} placeholder="200" />
            </label>

            <label className="form-label">
              Appliquer à
              <div className="form-grid">
                <div className="select-wrap">
                  <select className="form-select" value={targetType} onChange={(e) => setTargetType(e.target.value)}>
                    <option value="category">Catégorie</option>
                    <option value="article">Produit</option>
                    <option value="client">Client</option>
                  </select>
                </div>
                <div className="select-wrap">
                  <select className="form-select" value={effectiveTargetId} onChange={(e) => setTargetId(e.target.value)}>
                    {targetList.map((t) => (
                      <option key={t.id} value={t.id}>
                        {t.label}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
            </label>

            <div className="modal-foot">
              <button className="btn-ghost" type="button" onClick={onClose}>
                Annuler
              </button>
              <button className="btn-primary" type="submit" disabled={!canSubmit}>
                {initial ? 'Enregistrer' : 'Créer Promotion'}
              </button>
            </div>
          </div>

          <div className="promo-form-right">
            <div className="promo-preview">
              <div className="promo-preview-title">Aperçu</div>
              {name || value ? (
                <div className="promo-card-preview">
                  <div className="pc-top">
                    <div className="pc-val">{type === 'pourcentage' ? `-${value || 0}%` : `-${value || 0} DH`}</div>
                    {code && <div className="pc-code">{code}</div>}
                  </div>
                  <div className="pc-name">{name || 'Nouvelle Promotion'}</div>
                  <div className="pc-dates">
                    {startDate && <span>Du <b>{new Date(startDate).toLocaleDateString()}</b></span>}
                    {endDate && <span> au <b>{new Date(endDate).toLocaleDateString()}</b></span>}
                  </div>
                  
                  <div className="pc-target">
                     Applicable sur {targetType === 'category' ? 'Catégorie' : targetType === 'article' ? 'Produit' : 'Client'} : <b>{targetList.find(t => String(t.id) === String(effectiveTargetId))?.label || '—'}</b>
                  </div>
                  {Number(minPanier) > 0 && (
                    <div className="pc-min">Minimum d'achat: <b>{Number(minPanier).toFixed(2)} DH</b></div>
                  )}
                </div>
              ) : (
                <div className="promo-preview-box">
                  <Tag size={26} color="#94a3b8" />
                  <div className="promo-preview-text">L'aperçu s'affichera ici</div>
                </div>
              )}
            </div>
          </div>
        </form>
      </div>
    </div>
  )
}
