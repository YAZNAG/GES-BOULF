import { useState } from 'react'
import { X } from 'lucide-react'
import { apiFetch } from '../../lib/api'
import { toast } from '../../lib/toast'
import { MODES_PAIEMENT, json, money, today } from './format'

/** Règlement d'un fournisseur (diminue son crédit), éventuellement rattaché à une réception. */
export default function PaiementFournisseurModal({ open, fournisseur, reception, onClose, onDone }) {
  const du = reception ? Number(reception.reste || 0) : Number(fournisseur?.solde || 0)
  const [f, setF] = useState({ montant: '', mode: 'especes', date_paiement: today(), reference: '', note: '' })
  const [busy, setBusy] = useState(false)
  if (!open || !fournisseur) return null

  async function submit(e) {
    e.preventDefault()
    const montant = Number(String(f.montant).replace(',', '.'))
    if (!(montant > 0)) return toast({ type: 'error', message: 'Montant invalide.' })
    setBusy(true)
    try {
      await apiFetch('/api/achats/paiements', json('POST', { ...f, montant, fournisseur_id: fournisseur.id, reception_id: reception?.id || null }))
      toast({ type: 'success', message: `Règlement de ${money(montant)} DH enregistré.` })
      setF({ montant: '', mode: 'especes', date_paiement: today(), reference: '', note: '' })
      onDone?.()
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
          <div className="cx-modal-title">Régler {fournisseur.nom}</div>
          <button className="cx-icon-btn" type="button" onClick={onClose} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>
        <form className="cx-modal-body" onSubmit={submit}>
          <div className="cx-note" style={{ background: '#f8fafc', borderColor: '#e2e8f0', color: '#334155' }}>
            {reception ? `Reste dû sur ${reception.numero}` : 'Crédit fournisseur'} : <b>&nbsp;{money(du)} DH</b>
          </div>
          <div className="cx-two">
            <label className="cx-field">
              Montant (DH) *
              <input value={f.montant} autoFocus inputMode="decimal" onChange={(e) => setF({ ...f, montant: e.target.value })} placeholder={money(du)} />
            </label>
            <label className="cx-field">
              Mode
              <select value={f.mode} onChange={(e) => setF({ ...f, mode: e.target.value })}>
                {MODES_PAIEMENT.map((m) => (
                  <option key={m.value} value={m.value}>
                    {m.label}
                  </option>
                ))}
              </select>
            </label>
            <label className="cx-field">
              Date
              <input type="date" value={f.date_paiement} onChange={(e) => setF({ ...f, date_paiement: e.target.value })} />
            </label>
            <label className="cx-field">
              Référence (n° chèque, virement…)
              <input value={f.reference} onChange={(e) => setF({ ...f, reference: e.target.value })} />
            </label>
          </div>
          <label className="cx-field">
            Note
            <input value={f.note} onChange={(e) => setF({ ...f, note: e.target.value })} />
          </label>
          <div className="cx-modal-foot">
            {du > 0 ? (
              <button className="cx-btn" type="button" onClick={() => setF({ ...f, montant: du.toFixed(2) })}>
                Tout régler
              </button>
            ) : null}
            <button className="cx-btn cx-btn-primary" type="submit" disabled={busy}>
              {busy ? 'Enregistrement…' : 'Enregistrer le règlement'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
