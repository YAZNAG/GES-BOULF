import { useEffect, useState, useCallback } from 'react'
import { useParams, Link } from 'react-router-dom'
import { 
  User, 
  Phone, 
  Mail, 
  MapPin, 
  CreditCard, 
  FileText, 
  TrendingUp, 
  ChevronLeft,
  Calendar,
  DollarSign,
  AlertCircle
} from 'lucide-react'
import { apiFetch } from '../../lib/api'
import Alert from '../../components/Alert'
import '../../styles/clients.css'
import '../../styles/ventes.css'
import InvoiceModal from '../../components/InvoiceModal'

export default function ClientProfile() {
  const { clientId } = useParams()
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [selectedVente, setSelectedVente] = useState(null)
  const [isModalOpen, setIsModalOpen] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await apiFetch(`/api/clients/${clientId}/history`)
      setData(res)
    } catch (e) {
      setError(e?.message || 'Erreur lors du chargement du profil')
    } finally {
      setLoading(false)
    }
  }, [clientId])

  useEffect(() => {
    load()
  }, [load])

  if (loading) return <div className="content"><div className="products-empty">Chargement du profil…</div></div>
  if (error) return <div className="content"><Alert type="error" message={error} /></div>
  if (!data) return null

  const { client, ventes, total_spent } = data

  return (
    <section className="content">
      <div className="breadcrumb">
        <Link className="breadcrumb-link" to="/admin/clients">
          <ChevronLeft size={14} style={{ marginRight: '4px' }} />
          Retour aux clients
        </Link>
      </div>

      <div className="profile-top-section">
        <div className="profile-main-info">
          <div className="profile-header-card">
            <div className="profile-user-group">
              <div className="profile-avatar">
                <User size={40} color="#0f766e" />
              </div>
              <div>
                <h1 className="profile-name">{client.nom}</h1>
                <div className="profile-badges">
                  <span className="type-badge">{client.type_client === 'gros' ? 'Grossiste' : 'Détaillant'}</span>
                  <span className={client.actif ? 'status-badge status-livre' : 'status-badge status-annule'}>
                    {client.actif ? 'Compte Actif' : 'Compte Inactif'}
                  </span>
                </div>
              </div>
            </div>

            <div className="profile-contact-grid">
              <div className="info-item">
                <Phone size={18} color="#0f766e" />
                <div>
                  <div className="info-label">Téléphone</div>
                  <div className="info-val">{client.telephone || '—'}</div>
                </div>
              </div>
              <div className="info-item">
                <Mail size={18} color="#0f766e" />
                <div>
                  <div className="info-label">Email</div>
                  <div className="info-val">{client.email || '—'}</div>
                </div>
              </div>
              <div className="info-item">
                <MapPin size={18} color="#0f766e" />
                <div>
                  <div className="info-label">Adresse</div>
                  <div className="info-val">{client.adresse || '—'}</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="profile-stats-row">
          <div className="stat-card">
            <div className="stat-icon" style={{ backgroundColor: '#f0fdf4' }}>
              <TrendingUp size={24} color="#16a34a" />
            </div>
            <div>
              <div className="stat-label">Total Dépensé</div>
              <div className="stat-val">{(total_spent || 0).toFixed(2)} DH</div>
            </div>
          </div>
          <div className="stat-card">
            <div className="stat-icon" style={{ backgroundColor: Number(client.solde) > 0 ? '#fef2f2' : '#f0fdf4' }}>
              <CreditCard size={24} color={Number(client.solde) > 0 ? '#ef4444' : '#16a34a'} />
            </div>
            <div>
              <div className="stat-label">Solde Actuel</div>
              <div className="stat-val" style={{ color: Number(client.solde) > 0 ? '#ef4444' : '#16a34a' }}>
                {(Number(client.solde) || 0).toFixed(2)} DH
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="profile-bottom-section">
        <div className="profile-card">
          <div className="card-header-flex">
            <h3 className="card-title">Historique des Factures</h3>
            <div className="badge-count">{ventes?.length || 0} factures</div>
          </div>

          <div className="profile-table-wrap">
            <table className="profile-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>N° Facture</th>
                  <th>Montant</th>
                  <th>Statut</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {ventes && ventes.length > 0 ? (
                  ventes.map((v) => (
                    <tr key={v.id}>
                      <td>
                        <div className="date-cell">
                          <Calendar size={14} color="#94a3b8" />
                          {new Date(v.created_at).toLocaleDateString()}
                        </div>
                      </td>
                      <td className="fw-500">#{v.facture?.numero_facture || v.id}</td>
                      <td className="fw-bold">{Number(v.montant_total).toFixed(2)} DH</td>
                      <td>
                        <span className={v.facture?.statut === 'payée' ? 'status-badge status-livre' : 'status-badge status-encours'}>
                          {v.facture?.statut === 'payée' ? 'Payée' : 'Partiel/Non payée'}
                        </span>
                      </td>
                      <td>
                        <button 
                          type="button"
                          className="view-link btn-unstyled" 
                          onClick={() => {
                            setSelectedVente(v);
                            setIsModalOpen(true);
                          }}
                        >
                          <FileText size={16} />
                          Voir
                        </button>
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan="5" className="empty-row">Aucune facture trouvée pour ce client.</td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {isModalOpen && selectedVente && (
        <InvoiceModal 
          facture={selectedVente} 
          client={client}
          onClose={() => setIsModalOpen(false)} 
        />
      )}

      <style>{`
        .profile-top-section {
          display: grid;
          grid-template-columns: 1fr 340px;
          gap: 24px;
          margin-bottom: 24px;
        }
        .profile-main-info {
          display: flex;
          flex-direction: column;
          gap: 24px;
        }
        .profile-header-card {
          background: white;
          padding: 24px;
          border-radius: 12px;
          box-shadow: 0 1px 3px rgba(0,0,0,0.1);
          display: flex;
          flex-direction: column;
          gap: 24px;
        }
        .profile-user-group {
          display: flex;
          align-items: center;
          gap: 20px;
          padding-bottom: 20px;
          border-bottom: 1px solid #f1f5f9;
        }
        .profile-avatar {
          width: 70px;
          height: 70px;
          background: #f0fdfa;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          border: 2px solid #ccfbf1;
        }
        .profile-name {
          font-size: 24px;
          font-weight: 700;
          color: #1e293b;
          margin: 0 0 8px 0;
        }
        .profile-badges {
          display: flex;
          gap: 8px;
        }
        .profile-contact-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
          gap: 20px;
        }
        .info-item {
          display: flex;
          align-items: flex-start;
          gap: 12px;
        }
        .info-label {
          font-size: 11px;
          text-transform: uppercase;
          color: #64748b;
          font-weight: 600;
          margin-bottom: 2px;
        }
        .info-val {
          font-size: 14px;
          color: #1e293b;
          font-weight: 500;
        }
        .profile-stats-row {
          display: flex;
          flex-direction: column;
          gap: 16px;
        }
        .stat-card {
          background: white;
          padding: 20px;
          border-radius: 12px;
          box-shadow: 0 1px 3px rgba(0,0,0,0.1);
          display: flex;
          align-items: center;
          gap: 16px;
          flex: 1;
        }
        .stat-icon {
          width: 48px;
          height: 48px;
          border-radius: 12px;
          display: flex;
          align-items: center;
          justify-content: center;
        }
        .stat-label {
          font-size: 13px;
          color: #64748b;
          margin-bottom: 4px;
        }
        .stat-val {
          font-size: 18px;
          font-weight: 700;
          color: #1e293b;
        }
        .profile-bottom-section {
          width: 100%;
        }
        .profile-card {
          background: white;
          border-radius: 12px;
          padding: 24px;
          box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .card-title {
          font-size: 18px;
          font-weight: 600;
          color: #1e293b;
          margin: 0;
        }
        .card-header-flex {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 24px;
        }
        .badge-count {
          background: #f1f5f9;
          color: #475569;
          padding: 6px 14px;
          border-radius: 20px;
          font-size: 13px;
          font-weight: 600;
        }
        .profile-table-wrap {
          overflow-x: auto;
          margin: 0 -24px;
        }
        .profile-table {
          width: 100%;
          border-collapse: collapse;
        }
        .profile-table th {
          text-align: left;
          padding: 14px 24px;
          background: #f8fafc;
          color: #64748b;
          font-size: 12px;
          font-weight: 700;
          text-transform: uppercase;
          letter-spacing: 0.05em;
        }
        .profile-table td {
          padding: 18px 24px;
          border-bottom: 1px solid #f1f5f9;
          font-size: 14px;
          color: #1e293b;
        }
        .date-cell {
          display: flex;
          align-items: center;
          gap: 8px;
        }
        .view-link {
          display: flex;
          align-items: center;
          gap: 6px;
          color: #0f766e;
          font-weight: 600;
          text-decoration: none;
          cursor: pointer;
        }
        .btn-unstyled {
          background: none;
          border: none;
          padding: 0;
          font: inherit;
          cursor: pointer;
          outline: inherit;
        }
        .view-link:hover {
          color: #0d9488;
        }
        .empty-row {
          text-align: center;
          padding: 60px !important;
          color: #94a3b8;
          font-size: 15px;
        }
        @media (max-width: 1100px) {
          .profile-top-section {
            grid-template-columns: 1fr;
          }
          .profile-stats-row {
            flex-direction: row;
          }
        }
        @media (max-width: 640px) {
          .profile-stats-row {
            flex-direction: column;
          }
          .profile-contact-grid {
            grid-template-columns: 1fr;
          }
        }
      `}</style>
    </section>
  )
}
