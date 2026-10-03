import { useState } from 'react'
import { X } from 'lucide-react'

export function ClientModal({ open, editing, onClose, onSubmit, submitting }) {
  const [form, setForm] = useState(() => ({
    nom: editing?.nom || '',
    telephone: editing?.telephone || '',
    email: editing?.email || '',
    adresse: editing?.adresse || '',
    type_client: (editing?.type_client || 'detail').toString(),
    actif: Boolean(editing?.actif ?? true),
  }))

  if (!open) return null

  function handleSubmit(e) {
    e.preventDefault()
    onSubmit?.({
      nom: form.nom,
      telephone: form.telephone || null,
      email: form.email || null,
      adresse: form.adresse || null,
      type_client: form.type_client,
      actif: Boolean(form.actif),
    })
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-title">{editing ? 'Modifier le client' : 'Ajouter un client'}</div>
          <button className="modal-x" type="button" onClick={onClose} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>
        <form className="modal-body" onSubmit={handleSubmit}>
          <label className="form-label">
            Nom
            <input
              className="form-input"
              value={form.nom}
              onChange={(e) => setForm((p) => ({ ...p, nom: e.target.value }))}
              required
            />
          </label>

          <div className="form-grid">
            <label className="form-label">
              Téléphone
              <input
                className="form-input"
                value={form.telephone}
                onChange={(e) => setForm((p) => ({ ...p, telephone: e.target.value }))}
              />
            </label>

            <label className="form-label">
              Email
              <input
                className="form-input"
                type="email"
                value={form.email}
                onChange={(e) => setForm((p) => ({ ...p, email: e.target.value }))}
              />
            </label>
          </div>

          <div className="form-grid">
            <label className="form-label">
              Type client
              <select
                className="form-select"
                value={form.type_client}
                onChange={(e) => setForm((p) => ({ ...p, type_client: e.target.value }))}
              >
                <option value="detail">Détail</option>
                <option value="gros">Gros</option>
              </select>
            </label>

            <label className="form-label">
              Statut
              <select
                className="form-select"
                value={form.actif ? '1' : '0'}
                onChange={(e) => setForm((p) => ({ ...p, actif: e.target.value === '1' }))}
              >
                <option value="1">Actif</option>
                <option value="0">Inactif</option>
              </select>
            </label>
          </div>

          <label className="form-label">
            Adresse
            <input
              className="form-input"
              value={form.adresse}
              onChange={(e) => setForm((p) => ({ ...p, adresse: e.target.value }))}
            />
          </label>

          <div className="modal-foot">
            <button className="btn-ghost" type="button" onClick={onClose} disabled={submitting}>
              Annuler
            </button>
            <button className="btn-primary" type="submit" disabled={submitting}>
              Enregistrer
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
