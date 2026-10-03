import { CalendarDays, Pencil, Percent, Tag, Trash2, Truck, MessageCircle } from 'lucide-react'

function formatDateRange(start, end) {
  const s = start ? new Date(start) : null
  const e = end ? new Date(end) : null
  const fmt = (d) =>
    d
      ? `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`
      : ''
  if (!s && !e) return ''
  if (s && e) return `${fmt(s)} - ${fmt(e)}`
  return fmt(s || e)
}

function PromoIcon({ promo }) {
  if (promo.type === 'pourcentage') return <Percent size={20} color="#ffffff" />
  if (Number(promo.value) === 0) return <Truck size={20} color="#ffffff" />
  return <Tag size={20} color="#ffffff" />
}

function PromoValue({ promo }) {
  if (promo.type === 'pourcentage') return `${Number(promo.value)}%`
  return `${Number(promo.value)} DH`
}

function PromoTypeLabel({ promo }) {
  if (promo.type === 'pourcentage') return 'Pourcentage'
  if (Number(promo.value) === 0) return 'Livraison gratuite'
  return 'Montant fixe'
}

export function ViewPromotions({ visible, openEdit, openDelete, toggleStatus }) {
  const shareWhatsApp = (p) => {
    const value = p.type === 'pourcentage' ? `${p.value}%` : `${p.value} DH`
    const text = `🔥 *PROMO FLASH : ${p.name}* 🔥\n\n🎁 Avantage : *${value}* de réduction !\n📅 Valable jusqu'au : ${p.end_date ? new Date(p.end_date).toLocaleDateString() : 'Prochaine commande'}\n\nProfitez-en vite !`
    window.open(`https://wa.me/?text=${encodeURIComponent(text)}`, '_blank')
  }

  return (
    <div className="promo-list">
      {visible.length === 0 ? <div className="empty-state">Aucune promotion trouvée</div> : null}

      {visible.map((p) => (
        <div key={p.id} className="promo-card">
          <div className="promo-left">
            <div className="promo-icon">
              <PromoIcon promo={p} />
            </div>
            <div className="promo-info">
              <div className="promo-title-row">
                <div className="promo-title">{p.name}</div>
                <div className="promo-status-toggle">
                  <label className="toggle-switch mini-toggle">
                    <input 
                      type="checkbox" 
                      checked={!!p.is_active} 
                      onChange={() => toggleStatus(p)}
                    />
                    <span className="toggle-slider"></span>
                  </label>
                  <span className={p.is_active ? 'promo-status-text active' : 'promo-status-text'}>
                    {p.is_active ? 'Actif' : 'Inactif'}
                  </span>
                </div>
              </div>
              <div className="promo-meta">
                {p.code_promo ? <span className="promo-code">{p.code_promo}</span> : null}
                <span className="promo-meta-item">
                  <CalendarDays size={14} />
                  {formatDateRange(p.start_date, p.end_date)}
                </span>
                {Number(p.panier_min) > 0 ? <span className="promo-meta-item">Min: {Number(p.panier_min)} DH</span> : null}
                <span className="promo-meta-item">{p._targetLabel}</span>
              </div>
            </div>
          </div>

          <div className="promo-right">
            <div className="promo-value-section">
              <div className="promo-value">
                <div className="promo-value-big">
                  <PromoValue promo={p} />
                </div>
                <div className="promo-value-sub">
                  <PromoTypeLabel promo={p} />
                </div>
              </div>
              <button 
                className="promo-share-btn" 
                onClick={() => shareWhatsApp(p)}
                title="Partager sur WhatsApp"
              >
                <MessageCircle size={18} color="#25D366" />
              </button>
            </div>
            <div className="promo-actions">
              <button className="btn-icon" type="button" onClick={() => openEdit(p)} title="Modifier">
                <Pencil size={16} />
              </button>
              <button className="btn-icon btn-danger" type="button" onClick={() => openDelete(p)} title="Supprimer">
                <Trash2 size={16} />
              </button>
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}
