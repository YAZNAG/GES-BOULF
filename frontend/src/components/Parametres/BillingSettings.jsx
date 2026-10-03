import { useState } from 'react'
import { Save } from 'lucide-react'

export function BillingSettings({ settings, submitting, onSave }) {
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
      <div className="param-section-title">Options de facturation</div>
      
      <form className="param-form" onSubmit={handleSubmit}>
        <div className="param-grid-2">
          <label className="param-label">
            TVA par défaut (%)
            <input 
              className="param-input" 
              type="number"
              value={form.tva_default || ''} 
              onChange={e => handleChange('tva_default', e.target.value)} 
              placeholder="Ex: 20" 
            />
          </label>
          
          <label className="param-label">
            Préfixe des factures
            <input 
              className="param-input" 
              value={form.invoice_prefix || ''} 
              onChange={e => handleChange('invoice_prefix', e.target.value)}
              placeholder="Ex: FAC-" 
            />
          </label>
        </div>

        <label className="param-label">
          Notes ou Conditions (imprimées sur chaque facture)
          <textarea 
            className="param-input" 
            style={{height: '100px', resize: 'vertical', paddingTop: '10px'}}
            value={form.invoice_notes || ''} 
            onChange={e => handleChange('invoice_notes', e.target.value)} 
            placeholder="Merci pour votre confiance..." 
          />
        </label>

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
