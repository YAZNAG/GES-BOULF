import { Pencil, Trash2 } from 'lucide-react'

export function ViewUtilisateurs({ filteredUsers, statsByUserId, toggleActive, openEdit, askDelete, submitting, hasPermission }) {
  if (filteredUsers.length === 0) {
    return <div className="users-empty">Aucun utilisateur</div>
  }

  return (
    <div className="users-list">
      <div className="users-list-head">
        <div>Utilisateur</div>
        <div>Statut</div>
        <div>Commandes</div>
        <div>Total</div>
        <div>Actions</div>
      </div>

      {filteredUsers.map((u) => {
        const full = `${u.nom || ''} ${u.prenom || ''}`.trim() || '—'
        const initials = full
          .split(' ')
          .filter(Boolean)
          .slice(0, 2)
          .map((x) => x[0]?.toUpperCase())
          .join('')
        const s = statsByUserId.get(String(u.id)) || { count: 0, total: 0 }
        return (
          <div key={u.id} className="users-rowcard">
            <div className="users-cell users-cell-user">
              <div className="users-avatar">{initials || 'U'}</div>
              <div className="users-meta">
                <div className="users-name">{full}</div>
                <div className="users-sub">
                  <span>{u.email}</span>
                  <span>•</span>
                  <span>{u?.role?.nom || '—'}</span>
                </div>
              </div>
            </div>

            <div className="users-cell">
              <span className={u.actif ? 'users-badge users-badge-green' : 'users-badge users-badge-gray'}>
                {u.actif ? 'Actif' : 'Inactif'}
              </span>
            </div>

            <div className="users-cell users-metric">
              <div className="users-metric-value">{s.count}</div>
              <div className="users-metric-label">TOTAL</div>
            </div>

            <div className="users-cell users-metric">
              <div className="users-metric-value users-metric-value-red">{s.total.toLocaleString('fr-FR')}</div>
              <div className="users-metric-label">DH</div>
            </div>

            <div className="users-cell users-cell-actions">
              <button
                className={u.actif ? 'users-switch users-switch-on' : 'users-switch'}
                type="button"
                onClick={() => toggleActive(u)}
                aria-label="Activer / Désactiver"
                disabled={submitting || !hasPermission('utilisateurs.manage')}
              >
                <span className="users-switch-thumb" />
              </button>
              <button
                className="users-icon"
                type="button"
                onClick={() => openEdit(u)}
                aria-label="Modifier"
                disabled={!hasPermission('utilisateurs.manage')}
              >
                <Pencil size={18} />
              </button>
              <button
                className="users-icon users-icon-danger"
                type="button"
                onClick={() => askDelete(u)}
                aria-label="Supprimer"
                disabled={!hasPermission('utilisateurs.manage')}
              >
                <Trash2 size={18} />
              </button>
            </div>
          </div>
        )
      })}
    </div>
  )
}
