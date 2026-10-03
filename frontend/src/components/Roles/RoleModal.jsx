import { useState } from 'react'
import { X } from 'lucide-react'
import { PERM_GROUPS, uniq } from './rolesData'

export function RoleModal({ open, mode, initialValues, onClose, onSubmit }) {
  const [nom, setNom] = useState(() => initialValues?.nom ?? '')
  const [description, setDescription] = useState(() => initialValues?.description ?? '')
  const [selected, setSelected] = useState(() =>
    Array.isArray(initialValues?.permissions) ? initialValues.permissions : []
  )

  if (!open) return null

  const canSubmit = nom.trim().length > 0

  function toggle(key) {
    setSelected((prev) => {
      const set = new Set(prev.map(String))
      if (set.has(key)) set.delete(key)
      else set.add(key)
      return Array.from(set)
    })
  }

  function submit(e) {
    e.preventDefault()
    if (!canSubmit) return
    onSubmit?.({
      nom: nom.trim(),
      description: description.trim() ? description.trim() : null,
      permissions: uniq(selected),
    })
  }

  return (
    <div className="modal-overlay" onMouseDown={onClose}>
      <div className="modal roles-modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div>
            <div className="roles-modal-title">{mode === 'edit' ? 'Modifier le rôle' : 'Créer un nouveau rôle'}</div>
            <div className="roles-modal-sub">CONFIGURATION DES ACCÈS UTILISATEUR</div>
          </div>
          <button className="modal-x" type="button" onClick={onClose} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>

        <form className="modal-body" onSubmit={submit}>
          <div className="roles-form-grid">
            <label className="form-label">
              NOM DU RÔLE
              <input className="form-input" value={nom} onChange={(e) => setNom(e.target.value)} placeholder="Ex: Agent Livraison" />
            </label>
            <label className="form-label">
              DESCRIPTION
              <input
                className="form-input"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Décrivez les responsabilités de ce rôle..."
              />
            </label>
          </div>

          <div className="roles-perms-title">PERMISSIONS</div>

          <div className="roles-perms-grid">
            {PERM_GROUPS.map((g) => (
              <div key={g.key} className="roles-perm-card">
                <div className="roles-perm-head">{g.title}</div>
                <div className="roles-perm-list">
                  {g.perms.map((p) => (
                    <label key={p.key} className="roles-check">
                      <input
                        type="checkbox"
                        checked={selected.includes(p.key)}
                        onChange={() => toggle(p.key)}
                      />
                      <span>{p.label}</span>
                    </label>
                  ))}
                </div>
              </div>
            ))}
          </div>

          <div className="modal-foot">
            <button className="btn-ghost" type="button" onClick={onClose}>
              Annuler
            </button>
            <button className="btn-primary" type="submit" disabled={!canSubmit}>
              {mode === 'edit' ? 'Enregistrer' : 'Créer Rôle'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
