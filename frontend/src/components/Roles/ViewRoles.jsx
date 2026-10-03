import { Pencil, Trash2 } from 'lucide-react'
import { PERM_GROUPS, matrixResources, permissionLabel } from './rolesData'

export function ViewRoles({ roleCards, openEdit, askDelete }) {
  if (roleCards.length === 0) {
    return <div className="roles-empty">Aucun rôle</div>
  }

  return (
    <>
      <div className="roles-grid">
        {roleCards.map((r) => (
          <div key={r.id} className="roles-card">
            <div className="roles-card-top">
              <div>
                <div className="roles-card-title">
                  {r.nom}
                  <span className={r.badgeTone === 'red' ? 'roles-pill roles-pill-red' : 'roles-pill roles-pill-blue'}>
                    {r.usersCount}
                  </span>
                </div>
                <div className="roles-card-sub">{r.description || '—'}</div>
              </div>

              <div className="roles-actions">
                <button className="icon-pill" type="button" onClick={() => openEdit(r)} aria-label="Modifier">
                  <Pencil size={18} />
                </button>
                <button className="icon-pill icon-pill-danger" type="button" onClick={() => askDelete(r)} aria-label="Supprimer">
                  <Trash2 size={18} />
                </button>
              </div>
            </div>

            <div className="roles-card-block">
              <div className="roles-block-title">Permissions:</div>
              <div className="roles-chip-row">
                {PERM_GROUPS.map((g) => {
                  const p = permissionLabel(r.permissions, g.key)
                  if (p.tone === 'none') return null
                  const cls =
                    p.tone === 'full' ? 'roles-chip roles-chip-full' : p.tone === 'partial' ? 'roles-chip roles-chip-partial' : 'roles-chip'
                  return (
                    <div key={g.key} className={cls}>
                      {g.title}: {p.label}
                    </div>
                  )
                })}
                {Array.from(r.permissions).length === 0 ? <div className="roles-chip roles-chip-none">Aucune permission</div> : null}
              </div>
            </div>
          </div>
        ))}
      </div>

      <aside className="roles-side">
        <div className="roles-mini">
          <div className="roles-mini-ico">🛡️</div>
          <div className="roles-mini-meta">
            <div className="roles-mini-label">TOTAL RÔLES</div>
            <div className="roles-mini-value">{String(roleCards.length).padStart(2, '0')}</div>
          </div>
        </div>

        <div className="roles-help">
          <div className="roles-help-title">Aide Mémoire</div>
          <div className="roles-help-list">
            <div className="roles-help-item">
              <span className="roles-dot roles-dot-green" />
              <div>
                <div className="roles-help-strong">Complet:</div>
                <div className="roles-help-text">Accès total et lecture / écriture / suppression.</div>
              </div>
            </div>
            <div className="roles-help-item">
              <span className="roles-dot roles-dot-blue" />
              <div>
                <div className="roles-help-strong">Partiel:</div>
                <div className="roles-help-text">Lecture et modification autorisées, suppression interdite.</div>
              </div>
            </div>
            <div className="roles-help-item">
              <span className="roles-dot roles-dot-gray" />
              <div>
                <div className="roles-help-strong">Droit:</div>
                <div className="roles-help-text">Aucun accès au module sélectionné.</div>
              </div>
            </div>
          </div>
        </div>
      </aside>

      <div className="roles-matrix">
        <div className="roles-matrix-head">
          <div className="roles-matrix-title">Ressource</div>
          <div
            className="roles-matrix-cols"
            style={{ gridTemplateColumns: `repeat(${Math.max(1, roleCards.length)}, minmax(0, 1fr))` }}
          >
            {roleCards.map((r) => (
              <div key={r.id} className="roles-matrix-col">
                {r.nom}
              </div>
            ))}
          </div>
        </div>

        <div className="roles-matrix-body">
          {matrixResources.map((res) => (
            <div key={res.key} className="roles-matrix-row">
              <div className="roles-matrix-res">{res.label}</div>
              <div
                className="roles-matrix-cells"
                style={{ gridTemplateColumns: `repeat(${Math.max(1, roleCards.length)}, minmax(0, 1fr))` }}
              >
                {roleCards.map((r) => {
                  const p = permissionLabel(r.permissions, res.key)
                  const cls =
                    p.tone === 'full'
                      ? 'roles-badge roles-badge-full'
                      : p.tone === 'partial'
                        ? 'roles-badge roles-badge-partial'
                        : 'roles-badge roles-badge-none'
                  return (
                    <div key={`${res.key}-${r.id}`} className={cls}>
                      {p.label}
                    </div>
                  )
                })}
              </div>
            </div>
          ))}
        </div>
      </div>
    </>
  )
}
