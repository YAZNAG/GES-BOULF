import { useState } from 'react'
import { Save } from 'lucide-react'

export function SecuritySettings({ settings, submitting, onSave }) {
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
      <div className="param-section-title">Sécurité et Accès</div>
      
      <form className="param-form" onSubmit={handleSubmit}>
        
        <div style={{marginBottom: '10px'}}>
          <label style={{display: 'flex', alignItems: 'center', gap: '10px', fontSize: '13px', fontWeight: '600', color: '#0f172a', cursor: 'pointer'}}>
            <input 
              type="checkbox" 
              checked={form.mfa_enabled || false} 
              onChange={e => handleChange('mfa_enabled', e.target.checked)} 
              style={{width: '18px', height: '18px', accentColor: '#ef4444'}}
            />
            Exiger l&apos;authentification à deux facteurs (2FA) pour le compte Admin
          </label>
          <p className="param-hint" style={{marginTop: '6px', marginLeft: '28px'}}>Ajoute une couche de sécurité supplémentaire (Bientôt implémenté).</p>
        </div>

        <div className="param-grid-2">
          <label className="param-label">
            Expiration de session automatique (Minutes)
            <input 
              className="param-input" 
              type="number"
              value={form.session_timeout || ''} 
              onChange={e => handleChange('session_timeout', e.target.value)} 
              placeholder="Ex: 120" 
            />
            <span className="param-hint">L&apos;utilisateur sera déconnecté après cette durée d&apos;inactivité.</span>
          </label>

          <label className="param-label">
            Tentatives de connexion max
            <input 
              className="param-input" 
              type="number"
              value={form.max_login_attempts || ''} 
              onChange={e => handleChange('max_login_attempts', e.target.value)} 
              placeholder="Ex: 5" 
            />
            <span className="param-hint">Bloque l&apos;adresse IP temporairement après x échecs.</span>
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
