import React, { useState, useEffect } from 'react';
import { apiFetch } from '../../lib/api';
import { toast } from '../../lib/toast';
import { 
  FileText, 
  Download, 
  Eye, 
  Search,
  Filter,
  Calendar,
  User,
  CheckCircle,
  Clock,
  AlertCircle,
  X,
  RotateCcw
} from 'lucide-react';

import '../../styles/ventes.css';

export default function Factures() {
  const [factures, setFactures] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatut, setFilterStatut] = useState('all');
  const [selectedFacture, setSelectedFacture] = useState(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isReturnModalOpen, setIsReturnModalOpen] = useState(false);
  const [returningItem, setReturningItem] = useState(null);
  const [returningFacture, setReturningFacture] = useState(null);

  useEffect(() => {
    fetchFactures();
  }, []);

  const openDetails = (facture) => {
    setSelectedFacture(facture);
    setIsModalOpen(true);
  };

  const fetchFactures = async () => {
    setLoading(true);
    try {
      const response = await apiFetch('/api/factures?per_page=1000');
      const data = response?.data?.data || response?.data || response || [];
      setFactures(data);
    } catch {
      toast({ type: 'error', message: 'Erreur lors du chargement des factures' });
    } finally {
      setLoading(false);
    }
  };

  const filteredFactures = factures.filter(f => {
    const num = f.numero_facture || '';
    const clientName = f.vente?.client?.nom || 'Client de passage';
    const matchSearch = num.toLowerCase().includes(searchTerm.toLowerCase()) || 
                       clientName.toLowerCase().includes(searchTerm.toLowerCase());
    const matchStatut = filterStatut === 'all' || f.statut === filterStatut;
    return matchSearch && matchStatut;
  });

  const getStatutBadge = (statut) => {
    switch (statut) {
      case 'payée':
        return <span className="badge badge-success"><CheckCircle size={12} /> Payée</span>;
      case 'en_attente':
        return <span className="badge badge-warning"><Clock size={12} /> En attente</span>;
      case 'annulée':
        return <span className="badge badge-danger"><AlertCircle size={12} /> Annulée</span>;
      default:
        return <span className="badge badge-secondary">{statut}</span>;
    }
  };

  return (
    <div className="content factures-page">
      <div className="page-head">
        <div>
          <h1 className="page-title">
            <FileText size={28} color="#ef4444" />
            Factures
          </h1>
          <p className="page-subtitle">Gérez et consultez vos factures de vente</p>
        </div>
        <button className="btn-icon" onClick={fetchFactures} title="Actualiser">
          <RotateCcw size={18} />
        </button>
      </div>

      <div className="filters-card">
        <div className="filters-grid">
          <div className="search-box">
            <Search className="search-icon" size={20} />
            <input 
              type="text" 
              placeholder="Rechercher une facture ou un client..." 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <div className="filter-group">
            <label><Filter size={16} /> Statut:</label>
            <select value={filterStatut} onChange={(e) => setFilterStatut(e.target.value)}>
              <option value="all">Tous les statuts</option>
              <option value="payée">Payée</option>
              <option value="en_attente">En attente</option>
              <option value="annulée">Annulée</option>
            </select>
          </div>
        </div>
      </div>

      <div className="factures-card">
        {loading ? (
          <div className="loading-state">
            <div className="spinner"></div>
            Chargement des factures...
          </div>
        ) : filteredFactures.length === 0 ? (
          <div className="empty-state">
            <FileText size={48} strokeWidth={1} />
            <p>Aucune facture trouvée</p>
          </div>
        ) : (
          <div className="table-responsive">
            <table className="factures-table">
              <thead>
                <tr>
                  <th>N° Facture</th>
                  <th>Date</th>
                  <th>Client</th>
                  <th>Montant TTC</th>
                  <th>Statut</th>
                  <th className="text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredFactures.map(facture => (
                  <tr key={facture.id}>
                    <td style={{ fontWeight: 700, color: '#0f172a' }}>{facture.numero_facture}</td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <Calendar size={14} style={{ color: '#94a3b8' }} />
                        {new Date(facture.date_facture).toLocaleDateString()}
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <User size={14} style={{ color: '#94a3b8' }} />
                        {facture.vente?.client?.nom || 'Client de passage'}
                      </div>
                    </td>
                    <td style={{ fontWeight: 700 }}>{Number(facture.montant_ttc).toFixed(2)} MAD</td>
                    <td>{getStatutBadge(facture.statut)}</td>
                    <td className="text-right">
                      <div className="actions-buttons">
                        <button 
                          className="btn-icon" 
                          title="Voir détails"
                          onClick={() => openDetails(facture)}
                        >
                          <Eye size={18} />
                        </button>
                        <button 
                          className="btn-icon btn-primary" 
                          title="Imprimer / PDF" 
                          onClick={() => {
                            setSelectedFacture(facture);
                            setIsModalOpen(true);
                            // Give time for modal to render before printing
                            setTimeout(() => {
                                window.print();
                            }, 500);
                          }}
                        >
                          <Download size={18} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {isModalOpen && selectedFacture && (
        <InvoiceModal 
          facture={selectedFacture} 
          onClose={() => setIsModalOpen(false)} 
          onReturnItem={(item) => {
            setReturningItem(item);
            setReturningFacture(selectedFacture);
            setIsReturnModalOpen(true);
          }}
        />
      )}

      {isReturnModalOpen && returningItem && (
        <ReturnModal
          item={returningItem}
          facture={returningFacture}
          onClose={() => {
            setIsReturnModalOpen(false);
            setReturningItem(null);
          }}
          onSuccess={() => {
            setIsReturnModalOpen(false);
            setReturningItem(null);
            fetchFactures(); // Refresh data
          }}
        />
      )}
    </div>
  );
}

function InvoiceModal({ facture, onClose, onReturnItem }) {
  const items = facture.vente?.items || [];
  
  return (
    <div id="printable-invoice" className="modal-overlay" onClick={onClose}>
      <div className="modal invoice-modal" onClick={e => e.stopPropagation()}>
        <div className="modal-head no-print">
          <div className="modal-title">Aperçu de la Facture</div>
          <button className="modal-x" onClick={onClose}><X size={20} /></button>
        </div>
        <div className="modal-body invoice-body">
          {/* Invoice Header */}
          <div className="invoice-header">
            <div className="company-info">
              <div className="company-logo">EH</div>
              <div>
                <h2 className="company-name">EL HERRI</h2>
                <p className="company-details">Vente de produits alimentaires</p>
                <p className="company-details">Tél: 06 00 00 00 00 | Casablanca</p>
              </div>
            </div>
            <div className="invoice-meta">
              <div className="invoice-number">{facture.numero_facture}</div>
              <div className="invoice-date">Date: {new Date(facture.date_facture).toLocaleDateString()}</div>
            </div>
          </div>

          <div className="invoice-divider" />

          {/* Client & Bill Info */}
          <div className="invoice-info-grid">
            <div className="invoice-client">
              <div className="info-label">Client</div>
              <div className="client-name">{facture.vente?.client?.nom || 'Client de passage'}</div>
              {facture.vente?.client?.telephone && (
                <div className="client-tel">Tél: {facture.vente.client.telephone}</div>
              )}
              {facture.vente?.client?.adresse && (
                <div className="client-tel">{facture.vente.client.adresse}</div>
              )}
            </div>
            <div className="invoice-payment-info">
              <div className="info-label">Mode de paiement</div>
              <div className="payment-method" style={{ textTransform: 'capitalize' }}>{facture.vente?.mode_paiement || '—'}</div>
              <div className="info-label" style={{ marginTop: '12px' }}>Statut</div>
              <div className="payment-status">{facture.statut.toUpperCase()}</div>
            </div>
          </div>

          <div className="table-responsive" style={{ marginTop: '30px' }}>
            <table className="invoice-table">
              <thead>
                <tr>
                  <th>Article</th>
                  <th className="text-center">Prix Unitaire</th>
                  <th className="text-center">Qté</th>
                  <th className="text-right">Total</th>
                </tr>
              </thead>
              <tbody>
                {items.length > 0 ? items.map((item, index) => (
                  <tr key={index}>
                    <td>
                      <div className="item-name">{item.article?.nom || 'Article inconnu'}</div>
                      <div className="item-sku">{item.article?.code_article}</div>
                    </td>
                    <td className="text-center">{Number(item.prix_unitaire).toFixed(2)} MAD</td>
                    <td className="text-center">{item.quantite}</td>
                    <td className="text-right">{(item.quantite * item.prix_unitaire).toFixed(2)} MAD</td>
                  </tr>
                )) : (
                    <tr>
                        <td colSpan="4" className="text-center" style={{ padding: '20px', color: '#94a3b8' }}>Aucun article dans cette facture</td>
                    </tr>
                )}
              </tbody>
            </table>
          </div>

          <div className="invoice-summary-container">
            <div className="invoice-summary">
                <div className="summary-row">
                <span>Sous-total</span>
                <span>{Number(facture.montant_ttc).toFixed(2)} MAD</span>
                </div>
                <div className="summary-row">
                <span>Remise</span>
                <span>{Number(facture.vente?.montant_remise || 0).toFixed(2)} MAD</span>
                </div>
                <div className="summary-row total">
                <span>TOTAL TTC</span>
                <span>{Number(facture.montant_ttc).toFixed(2)} MAD</span>
                </div>
                {facture.vente && (
                <>
                    <div className="summary-row">
                    <span>Montant Payé</span>
                    <span>{Number(facture.vente.montant_paye).toFixed(2)} MAD</span>
                    </div>
                    <div className="summary-row balance">
                    <span>{Number(facture.vente.montant_total) > Number(facture.vente.montant_paye) ? 'Reste à payer' : 'Rendu'}</span>
                    <span>{Math.abs(Number(facture.vente.montant_total) - Number(facture.vente.montant_paye)).toFixed(2)} MAD</span>
                    </div>
                </>
                )}
            </div>
          </div>

          <div className="invoice-footer">
            <p>Merci pour votre achat !</p>
            <p className="footer-small">Cette facture est générée automatiquement par le système de gestion.</p>
          </div>
        </div>
        <div className="modal-foot no-print">
          <button className="btn-ghost" onClick={onClose}>Fermer</button>
          <button className="btn-primary" onClick={() => window.print()} style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Download size={18} /> Imprimer / PDF
          </button>
        </div>
      </div>
    </div>
  );
}
