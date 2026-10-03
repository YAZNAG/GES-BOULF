export function RolePicker({ roles, value, onChange }) {
  return (
    <div className="users-role-grid">
      {roles.map((r) => {
        const selected = String(value) === String(r.id)
        const label = (r.nom || '').toString()
        const letter = label ? label.slice(0, 1).toUpperCase() : '?'
        return (
          <button
            key={r.id}
            type="button"
            className={selected ? 'users-role-card users-role-card-active' : 'users-role-card'}
            onClick={() => onChange?.(String(r.id))}
          >
            <div className={selected ? 'users-role-ico users-role-ico-active' : 'users-role-ico'}>{letter}</div>
            <div className="users-role-name">{label}</div>
            {selected ? <div className="users-role-check">✓</div> : null}
          </button>
        )
      })}
    </div>
  )
}
