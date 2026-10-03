import { useState } from 'react'
import { X } from 'lucide-react'
import { RolePicker } from './RolePicker'

export function UserModal({ open, mode, roles, initialValues, onClose, onSubmit }) {
  const [nom, setNom] = useState(() => initialValues?.nom ?? '')
  const [prenom, setPrenom] = useState(() => initialValues?.prenom ?? '')
  const [email, setEmail] = useState(() => initialValues?.email ?? '')
  const [roleId, setRoleId] = useState(() => (initialValues?.role_id != null ? String(initialValues.role_id) : ''))
  const [password, setPassword] = useState('')
  const [actif, setActif] = useState(() => (initialValues?.actif != null ? !!initialValues.actif : true))

  if (!open) return null

  const canSubmit = nom.trim() && email.trim() && roleId && (mode === 'edit' ? true : password.trim().length >= 6)

  function submit(e) {
    e.preventDefault()
    if (!canSubmit) return
    onSubmit?.({
      nom: nom.trim(),
      prenom: prenom.trim() ? prenom.trim() : null,
      email: email.trim(),
      role_id: Number(roleId),
      mot_de_passe: mode === 'edit' ? (password.trim() ? password.trim() : null) : password.trim(),
      actif,
    })
  }

  return (
    <div className="users-modal-overlay" onMouseDown={onClose}>
      <div className="users-modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="users-modal-head">
          <div className="users-modal-title">{mode === 'edit' ? "Modifier un utilisateur" : 'Ajouter un utilisateur'}</div>
          <button className="users-modal-x" type="button" onClick={onClose} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>

        <form className="users-modal-body" onSubmit={submit}>
          <label className="users-field">
            Adresse email
            <input className="users-input" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="exemple@email.com" />
          </label>

          <div className="users-row">
            <label className="users-field">
              Nom
              <input className="users-input" value={nom} onChange={(e) => setNom(e.target.value)} placeholder="Nom" />
            </label>
            <label className="users-field">
              Prénom
              <input className="users-input" value={prenom} onChange={(e) => setPrenom(e.target.value)} placeholder="Prénom" />
            </label>
          </div>

          <div className="users-field">
            Rôle
            <RolePicker roles={roles} value={roleId} onChange={setRoleId} />
          </div>

          <label className="users-field">
            Mot de passe{mode === 'edit' ? ' (optionnel)' : ''}
            <input
              className="users-input"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder={mode === 'edit' ? 'Laisser vide pour ne pas changer' : 'Min 6 caractères'}
              type="password"
            />
          </label>

          <div className="users-note">
            Un email d&apos;invitation peut être envoyé plus tard. Pour l&apos;instant, définis un mot de passe.
          </div>

          <label className="users-active-line">
            <input type="checkbox" checked={actif} onChange={(e) => setActif(e.target.checked)} />
            <span>Utilisateur actif</span>
          </label>

          <div className="users-modal-actions">
            <button className="users-btn users-btn-ghost" type="button" onClick={onClose}>
              Annuler
            </button>
            <button className="users-btn users-btn-primary" type="submit" disabled={!canSubmit}>
              {mode === 'edit' ? 'Enregistrer' : 'Envoyer invitation'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
