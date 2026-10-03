export function ConfirmModal({ open, onClose, onConfirm, title, description, confirmLabel, disabled }) {
  if (!open) return null
  return (
    <div className="modal-overlay" onMouseDown={onClose}>
      <div className="modal" style={{ maxWidth: '400px' }} onMouseDown={(e) => e.stopPropagation()}>
        <div className="confirm-title" style={{ fontSize: '1.25rem', fontWeight: 600, padding: '1.5rem 1.5rem 0.5rem' }}>{title}</div>
        <div className="confirm-desc" style={{ color: '#64748b', padding: '0 1.5rem 1.5rem' }}>{description}</div>
        <div className="modal-foot">
          <button className="btn-ghost" type="button" onClick={onClose} disabled={disabled}>
            Annuler
          </button>
          <button className="btn-danger" type="button" onClick={onConfirm} disabled={disabled}>
            {confirmLabel || 'Confirmer'}
          </button>
        </div>
      </div>
    </div>
  )
}
