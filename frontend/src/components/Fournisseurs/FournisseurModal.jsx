import { useState } from 'react'
import { X } from 'lucide-react'

export function FournisseurModal({ open, editing, onClose, onSubmit, submitting }) {
  const [form, setForm] = useState(() => ({
    nom: editing?.nom || '',
    telephone: editing?.telephone || '',
    email: editing?.email || '',
    adresse: editing?.adresse || '',
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
      actif: Boolean(form.actif),
    })
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-title">
            {editing ? "Modifier le fournisseur" : "Ajouter un fournisseur"}
          </div>
          <button
            className="modal-x"
            type="button"
            onClick={onClose}
            aria-label="Fermer"
          >
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

          <label className="form-label">
            Adresse
            <input
              className="form-input"
              value={form.adresse}
              onChange={(e) => setForm((p) => ({ ...p, adresse: e.target.value }))}
            />
          </label>

          <label className="form-label">
            Statut
            <select
              className="form-select"
              value={form.actif ? "1" : "0"}
              onChange={(e) => setForm((p) => ({ ...p, actif: e.target.value === "1" }))}
            >
              <option value="1">Actif</option>
              <option value="0">Inactif</option>
            </select>
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
