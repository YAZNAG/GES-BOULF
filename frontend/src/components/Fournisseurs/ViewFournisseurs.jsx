import { Pencil, Trash2 } from 'lucide-react'

export function ViewFournisseurs({ filtered, openEdit, openDelete }) {
  return (
    <div className="fournisseurs-table-wrap">
      <table className="fournisseurs-table">
        <thead>
          <tr>
            <th>id</th>
            <th>Nom</th>
            <th>Téléphone</th>
            <th>Email</th>
            <th>Adresse</th>
            <th>Statut</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {filtered.map((f) => (
            <tr key={f.id}>
              <td style={{ fontWeight: 'bolder' }}>{f.id}</td>
              <td className="fw-500">{f.nom}</td>
              <td>{f.telephone || "—"}</td>
              <td>{f.email || "—"}</td>
              <td>{f.adresse || "—"}</td>
              <td>
                <span
                  className={
                    f.actif
                      ? "status-badge status-livre"
                      : "status-badge status-annule"
                  }
                >
                  {f.actif ? "Actif" : "Inactif"}
                </span>
              </td>
              <td>
                <div className="fournisseurs-actions">
                  <button
                    className="icon-pill"
                    type="button"
                    onClick={() => openEdit(f)}
                    aria-label="Modifier"
                  >
                    <Pencil size={18} />
                  </button>
                  <button
                    className="icon-pill icon-pill-danger"
                    type="button"
                    onClick={() => openDelete(f)}
                    aria-label="Supprimer"
                  >
                    <Trash2 size={18} />
                  </button>
                </div>
              </td>
            </tr>
          ))}
          {filtered.length === 0 ? (
            <tr>
              <td colSpan="7" className="fournisseurs-empty-cell">
                Aucun fournisseur
              </td>
            </tr>
          ) : null}
        </tbody>
      </table>
    </div>
  )
}
