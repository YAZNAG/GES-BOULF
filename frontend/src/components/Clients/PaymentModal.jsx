import React, { useState } from 'react';
import { X, CreditCard } from 'lucide-react';

export function PaymentModal({ open, client, onClose, onSubmit, submitting }) {
  const [amount, setAmount] = useState(() => (client?.solde != null ? String(client.solde) : ''));
  const [mode, setMode] = useState('espèces');
  const [note, setNote] = useState('');

  if (!open) return null;

  const handleSubmit = (e) => {
    e.preventDefault();
    onSubmit({
      montant: Number(amount),
      mode,
      note
    });
  };

  return (
    <div className="modal-overlay">
      <div className="modal">
        <div className="modal-head">
          <h2 className="modal-title">
            <CreditCard size={20} />
            Enregistrer un paiement
          </h2>
          <button className="modal-close" onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="payment-form">
          <div className="modal-body">
            <div className="client-info-box">
              <p className="client-info-label">Client:</p>
              <p className="client-info-name">{client?.nom}</p>
              <p className="client-info-debt">Dette actuelle: {Number(client?.solde || 0).toFixed(2)} MAD</p>
            </div>

            <div className="form-group">
              <label className="form-label">Montant du paiement (MAD)</label>
              <input
                type="number"
                step="0.01"
                className="form-input"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="0.00"
                required
                autoFocus
                max={client?.solde}
              />
              {Number(amount) > Number(client?.solde) && (
                <p style={{ color: '#ef4444', fontSize: '12px', marginTop: '6px', fontWeight: 600 }}>
                  Le montant ne peut pas dépasser la dette ({Number(client?.solde).toFixed(2)} MAD)
                </p>
              )}
            </div>

            <div className="form-group">
              <label className="form-label">Mode de paiement</label>
              <select 
                className="form-input" 
                value={mode} 
                onChange={(e) => setMode(e.target.value)}
              >
                <option value="espèces">Espèces</option>
                <option value="carte">Carte</option>
                <option value="virement">Virement</option>
                <option value="chèque">Chèque</option>
              </select>
            </div>

            <div className="form-group" style={{ marginBottom: 0 }}>
              <label className="form-label">Note / Référence</label>
              <textarea
                className="form-input"
                rows="2"
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder="Ex: Chèque n°123..."
              ></textarea>
            </div>
          </div>

          <div className="modal-foot">
            <button type="button" className="btn-ghost" onClick={onClose} disabled={submitting}>
              Annuler
            </button>
            <button type="submit" className="btn-primary" disabled={submitting || !amount || Number(amount) <= 0 || Number(amount) > Number(client?.solde)}>
              {submitting ? 'Enregistrement...' : 'Confirmer le paiement'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
