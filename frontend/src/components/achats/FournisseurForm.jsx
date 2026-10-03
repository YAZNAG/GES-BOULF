import { useState } from 'react'
import { X } from 'lucide-react'
import { apiFetch } from '../../lib/api'
import { toast } from '../../lib/toast'
import { json } from './format'

const EMPTY = { code: '', nom: '', contact: '', telephone: '', email: '', adresse: '', ville: '', ice: '', rc: '', plafond_credit: '', delai_paiement: '', note: '', actif: true }

/** Création / modification d'un fournisseur. Le crédit (solde) n'est jamais saisi à la main. */
export default function FournisseurForm({ open, fournisseur, onClose, onSaved }) {
  const [f, setF] = useState(() => ({ ...EMPTY, ...clean(fournisseur) }))
  const [busy, setBusy] = useState(false)
  if (!open) return null

  async function submit(e) {
    e.preventDefault()
    if (!f.nom.trim()) return toast({ type: 'error', message: 'Le nom est obligatoire.' })
    setBusy(true)
    try {
      const body = {
        ...f,
        plafond_credit: f.plafond_credit === '' ? null : Number(f.plafond_credit),
        delai_paiement: f.delai_paiement === '' ? null : Number(f.delai_paiement),
        email: f.email || null,
      }
      const saved = await apiFetch(fournisseur ? `/api/fournisseurs/${fournisseur.id}` : '/api/fournisseurs', json(fournisseur ? 'PUT' : 'POST', body))
      toast({ type: 'success', message: fournisseur ? 'Fournisseur modifié.' : 'Fournisseur ajouté.' })
      onSaved?.(saved)
    } catch (err) {
      toast({ type: 'error', message: err.message })
    } finally {
      setBusy(false)
    }
  }

  const field = (k, label, props = {}) => (
    <label className="cx-field">
      {label}
      <input value={f[k] ?? ''} onChange={(e) => setF({ ...f, [k]: e.target.value })} {...props} />
    </label>
  )

  return (
    <div className="cx-modal-back" onMouseDown={onClose}>
      <div className="cx-modal" style={{ maxWidth: 640 }} role="dialog" aria-modal="true" onMouseDown={(e) => e.stopPropagation()}>
        <div className="cx-modal-head">
          <div className="cx-modal-title">{fournisseur ? 'Modifier le fournisseur' : 'Nouveau fournisseur'}</div>
          <button className="cx-icon-btn" type="button" onClick={onClose} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>
        <form className="cx-modal-body" onSubmit={submit}>
          <div className="cx-two">
            {field('nom', 'Raison sociale *', { autoFocus: true })}
            {field('code', 'Code interne')}
            {field('contact', 'Personne à contacter')}
            {field('telephone', 'Téléphone', { inputMode: 'tel' })}
            {field('email', 'E-mail', { type: 'email' })}
            {field('ville', 'Ville')}
            {field('ice', 'ICE')}
            {field('rc', 'RC')}
            {field('plafond_credit', 'Plafond de crédit (DH)', { inputMode: 'decimal', placeholder: 'illimité' })}
            {field('delai_paiement', 'Délai de paiement (jours)', { inputMode: 'numeric', placeholder: 'ex. 30' })}
          </div>
          {field('adresse', 'Adresse')}
          {field('note', 'Note')}
          <label className="cx-field" style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
            <input type="checkbox" checked={!!f.actif} onChange={(e) => setF({ ...f, actif: e.target.checked })} style={{ width: 18, height: 18 }} />
            Fournisseur actif
          </label>
          <div className="cx-modal-foot">
            <button className="cx-btn" type="button" onClick={onClose}>
              Annuler
            </button>
            <button className="cx-btn cx-btn-primary" type="submit" disabled={busy}>
              {busy ? 'Enregistrement…' : 'Enregistrer'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

function clean(f) {
  if (!f) return {}
  const out = {}
  Object.keys(EMPTY).forEach((k) => (out[k] = f[k] ?? EMPTY[k]))
  return out
}
