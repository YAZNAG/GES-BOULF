import { useState } from 'react'
import { Save } from 'lucide-react'

export function NotificationSettings({ settings, submitting, onSave }) {
  const [form, setForm] = useState(() => ({ ...(settings || {}) }))

  function handleChange(field, value) {
    setForm(prev => ({ ...prev, [field]: value }))
  }

  function handleSubmit(e) {
    e.preventDefault()
    onSave(form)
  }

  return (
    <div>
      <div className="param-section-title">Préférences de Notification</div>
      
      <form className="param-form" onSubmit={handleSubmit}>
        
        <div style={{display: 'flex', flexDirection: 'column', gap: '15px', marginBottom: '20px'}}>
          <label style={{display: 'flex', alignItems: 'center', gap: '10px', fontSize: '13px', fontWeight: '600', color: '#0f172a', cursor: 'pointer'}}>
            <input 
              type="checkbox" 
              checked={form.notify_email || false} 
              onChange={e => handleChange('notify_email', e.target.checked)} 
              style={{width: '18px', height: '18px', accentColor: '#3b82f6'}}
            />
            M&apos;alerter par Email pour chaque nouvelle commande
          </label>
        </div>

        <div className="param-grid-2">
          <label className="param-label">
            Alerte automatique de Stock bas (Quantité)
            <input 
              className="param-input" 
              type="number"
              value={form.stock_alert || ''} 
              onChange={e => handleChange('stock_alert', e.target.value)} 
              placeholder="Ex: 10" 
            />
            <span className="param-hint">Une notification sera envoyée quand un produit atteint ce seuil.</span>
          </label>
        </div>

        <div className="param-actions">
          <button className="param-btn-save" type="submit" disabled={submitting}>
            <Save size={16} />
            {submitting ? 'Sauvegarde...' : 'Sauvegarder les modifications'}
          </button>
        </div>
      </form>
    </div>
  )
}
