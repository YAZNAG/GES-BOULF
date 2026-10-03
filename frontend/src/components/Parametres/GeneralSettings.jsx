import { useState } from 'react'
import { Save } from 'lucide-react'

export function GeneralSettings({ settings, submitting, onSave }) {
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
      <div className="param-section-title">Paramètres Généraux</div>
      
      <form className="param-form" onSubmit={handleSubmit}>
        <div className="param-grid-2">
          <label className="param-label">
            Nom de l&apos;entreprise
            <input 
              className="param-input" 
              value={form.nom_entreprise || ''} 
              onChange={e => handleChange('nom_entreprise', e.target.value)} 
              placeholder="Ex: Mon Magasin" 
            />
          </label>
          
          <label className="param-label">
            Devise Principale
            <select 
              className="param-select" 
              value={form.devise || 'MAD'} 
              onChange={e => handleChange('devise', e.target.value)}
            >
              <option value="MAD">Dirham Marocain (MAD)</option>
              <option value="EUR">Euro (€)</option>
              <option value="USD">Dollar Américain ($)</option>
            </select>
          </label>
        </div>

        <div className="param-grid-2">
          <label className="param-label">
            Email de contact
            <input 
              className="param-input" 
              type="email"
              value={form.email_contact || ''} 
              onChange={e => handleChange('email_contact', e.target.value)} 
            />
          </label>

          <label className="param-label">
            Téléphone
            <input 
              className="param-input" 
              type="tel"
              value={form.telephone || ''} 
              onChange={e => handleChange('telephone', e.target.value)} 
            />
          </label>
        </div>

        <label className="param-label">
          Adresse complète
          <input 
            className="param-input" 
            value={form.adresse || ''} 
            onChange={e => handleChange('adresse', e.target.value)} 
            placeholder="Rue, Ville, Code Postal" 
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
