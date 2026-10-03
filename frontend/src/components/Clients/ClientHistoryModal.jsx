import React from 'react';
import { X, Calendar, FileText, ArrowDownCircle, ArrowUpCircle } from 'lucide-react';

export function ClientHistoryModal({ open, client, history, onClose }) {
  if (!open || !client) return null;

  const allEvents = [
    ...history.ventes.map(v => ({
      type: 'vente',
      date: v.created_at,
      label: `Vente ${v.facture?.numero_facture || ''}`,
      amount: v.montant_total,
      paid: v.montant_paye,
      status: v.montant_total > v.montant_paye ? 'credit' : 'paid'
    })),
    ...history.paiements.map(p => ({
      type: 'paiement',
      date: p.created_at,
      label: `Paiement (${p.mode})`,
      amount: p.montant,
      note: p.note
    }))
  ].sort((a, b) => new Date(b.date) - new Date(a.date));

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()} style={{ width: '700px', maxWidth: '95%' }}>
        <div className="modal-head">
          <div className="modal-title">Historique de {client.nom}</div>
          <button className="modal-close" onClick={onClose}><X size={20} /></button>
        </div>
        <div className="modal-body">
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '25px', padding: '15px', background: '#f8fafc', borderRadius: '12px' }}>
            <div>
              <p style={{ color: '#64748b', fontSize: '13px' }}>Type Client</p>
              <p style={{ fontWeight: 700, textTransform: 'capitalize' }}>{client.type_client || 'Détail'}</p>
            </div>
            <div>
              <p style={{ color: '#64748b', fontSize: '13px' }}>Téléphone</p>
              <p style={{ fontWeight: 700 }}>{client.telephone || '-'}</p>
            </div>
            <div style={{ textAlign: 'right' }}>
              <p style={{ color: '#64748b', fontSize: '13px' }}>Solde Actuel</p>
              <p style={{ fontWeight: 800, fontSize: '18px', color: client.solde > 0 ? '#ef4444' : '#16a34a' }}>
                {Number(client.solde).toFixed(2)} MAD
              </p>
            </div>
          </div>

          <div className="history-timeline">
            <h4 style={{ marginBottom: '15px', fontWeight: 700 }}>Activités Récentes</h4>
            {allEvents.length === 0 ? (
              <p style={{ textAlign: 'center', color: '#64748b', padding: '20px' }}>Aucune activité trouvée</p>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                {allEvents.map((event, idx) => (
                  <div key={idx} style={{ 
                    display: 'flex', 
                    alignItems: 'center', 
                    padding: '12px', 
                    background: 'white', 
                    border: '1px solid #e2e8f0', 
                    borderRadius: '10px' 
                  }}>
                    <div style={{ 
                      width: '36px', 
                      height: '36px', 
                      borderRadius: '8px', 
                      display: 'flex', 
                      alignItems: 'center', 
                      justifyContent: 'center',
                      marginRight: '15px',
                      background: event.type === 'vente' ? '#fef2f2' : '#f0fdf4',
                      color: event.type === 'vente' ? '#ef4444' : '#16a34a'
                    }}>
                      {event.type === 'vente' ? <ArrowUpCircle size={20} /> : <ArrowDownCircle size={20} />}
                    </div>
                    <div style={{ flex: 1 }}>
                      <p style={{ fontWeight: 700, fontSize: '14px' }}>{event.label}</p>
                      <p style={{ fontSize: '12px', color: '#64748b' }}>
                        <Calendar size={12} style={{ display: 'inline', marginRight: '4px' }} />
                        {new Date(event.date).toLocaleDateString()} {new Date(event.date).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </p>
                    </div>
                    <div style={{ textAlign: 'right' }}>
                      <p style={{ fontWeight: 800, color: event.type === 'vente' ? '#1e293b' : '#16a34a' }}>
                        {event.type === 'vente' ? `-${Number(event.amount).toFixed(2)}` : `+${Number(event.amount).toFixed(2)}`} MAD
                      </p>
                      {event.type === 'vente' && event.status === 'credit' && (
                        <span style={{ fontSize: '11px', color: '#ef4444', fontWeight: 700 }}>Crédit: {(event.amount - event.paid).toFixed(2)} MAD</span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
        <div className="modal-foot">
          <button className="btn btn-light" onClick={onClose}>Fermer</button>
        </div>
      </div>
    </div>
  );
}
