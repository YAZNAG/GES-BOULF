import React from 'react';
import { X, Download } from 'lucide-react';

export default function InvoiceModal({ facture, client: propClient, onClose }) {
  if (!facture) return null;
  
  // Normalize data
  const isVente = !!facture.items;
  const displayFacture = isVente ? (facture.facture || facture) : facture;
  const vente = isVente ? facture : (facture.vente || null);
  const items = (vente?.items || facture.items || []);
  const client = propClient || vente?.client || displayFacture?.vente?.client;
  
  const numero = displayFacture.numero_facture || displayFacture.numero || `FAC-${displayFacture.id}`;
  const dateStr = displayFacture.date_facture || displayFacture.created_at;

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
              <div className="invoice-number">{numero}</div>
              <div className="invoice-date">Date: {new Date(dateStr).toLocaleDateString()}</div>
            </div>
          </div>

          <div className="invoice-divider" />

          {/* Client & Bill Info */}
          <div className="invoice-info-grid">
            <div className="invoice-client">
              <div className="info-label">Client</div>
              <div className="client-name">{client?.nom || 'Client de passage'}</div>
              {client?.telephone && (
                <div className="client-tel">Tél: {client.telephone}</div>
              )}
              {client?.adresse && (
                <div className="client-tel">{client.adresse}</div>
              )}
            </div>
            <div className="invoice-payment-info">
              <div className="info-label">Mode de paiement</div>
              <div className="payment-method" style={{ textTransform: 'capitalize' }}>{vente?.mode_paiement || '—'}</div>
              <div className="info-label" style={{ marginTop: '12px' }}>Statut</div>
              <div className="payment-status">{(displayFacture.statut || 'Payée').toUpperCase()}</div>
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
                <span>{Number(displayFacture.montant_ttc || vente?.montant_total).toFixed(2)} MAD</span>
                </div>
                <div className="summary-row">
                <span>Remise</span>
                <span>{Number(vente?.montant_remise || 0).toFixed(2)} MAD</span>
                </div>
                <div className="summary-row total">
                <span>TOTAL TTC</span>
                <span>{Number(displayFacture.montant_ttc || vente?.montant_total).toFixed(2)} MAD</span>
                </div>
                {vente && (
                <>
                    <div className="summary-row">
                    <span>Montant Payé</span>
                    <span>{Number(vente.montant_paye).toFixed(2)} MAD</span>
                    </div>
                    <div className="summary-row balance">
                    <span>{Number(vente.montant_total) > Number(vente.montant_paye) ? 'Reste à payer' : 'Rendu'}</span>
                    <span>{Math.abs(Number(vente.montant_total) - Number(vente.montant_paye)).toFixed(2)} MAD</span>
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
