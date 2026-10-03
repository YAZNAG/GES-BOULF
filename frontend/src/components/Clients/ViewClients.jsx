import { Pencil, Trash2, CreditCard, History, User } from 'lucide-react'
import { Link } from 'react-router-dom'

export function ViewClients({ filtered, openEdit, openDelete, openPayment, openHistory }) {
  function typeLabel(t) {
    return t === 'gros' ? 'Gros' : 'Détail'
  }

  return (
    <div className="clients-table-wrap">
      <table className="clients-table">
        <thead>
          <tr>
            <th>id</th>
            <th>Nom</th>
            <th>Téléphone</th>
            <th>Type</th>
            <th>Solde (MAD)</th>
            <th>Adresse</th>
            <th>Statut</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {filtered.map((c) => (
            <tr key={c.id}>
              <td style={{ fontWeight: 'bolder' }}>{c.id}</td>
              <td className="fw-500">{c.nom}</td>
              <td>{c.telephone || '—'}</td>
              <td>
                <span className="type-badge">{typeLabel((c?.type_client || 'detail').toString())}</span>
              </td>
              <td style={{ fontWeight: 'bold', color: Number(c.solde) > 0 ? '#ef4444' : '#10b981' }}>
                {Number(c.solde || 0).toFixed(2)}
              </td>
              <td>{c.adresse || '—'}</td>
              <td>
                <span className={c.actif ? 'status-badge status-livre' : 'status-badge status-annule'}>
                  {c.actif ? 'Actif' : 'Inactif'}
                </span>
              </td>
              <td>
                <div className="clients-actions">
                  <Link 
                    to={`/admin/clients/${c.id}/profile`}
                    className="icon-pill" 
                    title="Voir le profil complet"
                  >
                    <User size={18} />
                  </Link>
                  <button 
                    className="icon-pill" 
                    type="button" 
                    onClick={() => openHistory(c)} 
                    aria-label="Historique"
                    title="Voir l'historique"
                  >
                    <History size={18} />
                  </button>
                  {Number(c.solde) > 0 && (
                    <button 
                      className="icon-pill" 
                      type="button" 
                      onClick={() => openPayment(c)} 
                      aria-label="Enregistrer un paiement"
                      title="Enregistrer un paiement"
                      style={{ color: '#10b981' }}
                    >
                      <CreditCard size={18} />
                    </button>
                  )}
                  <button className="icon-pill" type="button" onClick={() => openEdit(c)} aria-label="Modifier">
                    <Pencil size={18} />
                  </button>
                  <button
                    className="icon-pill icon-pill-danger"
                    type="button"
                    onClick={() => openDelete(c)}
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
              <td colSpan="8" className="clients-empty-cell">
                Aucun client
              </td>
            </tr>
          ) : null}
        </tbody>
      </table>
    </div>
  )
}
