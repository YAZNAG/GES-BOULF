import { Edit, Eye, Trash2 } from "lucide-react"

export const ViewCommandes = (props)=>{



    return (
         <div className="orders-table-wrap">
                    <table className="orders-table">
                      <thead>
                        <tr>
                          <th>Numéro</th>
                          <th>Client</th>
                          <th>Type</th>
                          <th>Statut</th>
                          <th>Total</th>
                          <th>Date</th>
                          <th>Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {props.filteredCommandes.map((cmd) => (
                          <tr key={cmd.id} >
                            <td className="fw-500">{cmd.numero || `#ORD-${cmd.id}`}</td>
                            <td>{cmd.client ? cmd.client.nom : "Client inconnu"}</td>
                            <td>{props.getTypeBadge(cmd.type_commande)}</td>
                            <td>{props.getStatusBadge(cmd.statut)}</td>
                            <td>{cmd.total} DH</td>
                            <td>{props.formatDate(cmd.date_commande || cmd.created_at)}</td>
                            <td>
                              <div className="orders-actions">
                                <button
                                  className="icon-pill"
                                  type="button"
                                  onClick={() => props.handleView(cmd)}
                                  aria-label="Voir"
                                >
                                  <Eye size={18} />
                                </button>
                                <button
                                  className="icon-pill"
                                  type="button"
                                  onClick={() => props.handleEdit(cmd)}
                                  aria-label="Modifier"
                                >
                                  <Edit size={18} />
                                </button>
                                <button
                                  className="icon-pill icon-pill-danger"
                                  type="button"
                                  onClick={() => props.handleDelete(cmd)}
                                  aria-label="Supprimer"
                                >
                                  <Trash2 size={18} />
                                </button>
                              </div>
                            </td>
                          </tr>
                        ))}
                        {props.filteredCommandes.length === 0 && (
                          <tr>
                            <td colSpan="7" className="orders-empty-cell">
                              Aucune commande trouvée
                            </td>
                          </tr>
                        )}
                      </tbody>
                    </table>
                  </div>
    )
}