import { X } from 'lucide-react'

export default function ConfirmDialog({ open, title, message, confirmLabel = 'Supprimer', onConfirm, onCancel }) {
  if (!open) return null

  return (
    <div className="modal-overlay" onMouseDown={onCancel}>
      <div className="modal" style={{ maxWidth: '420px' }} onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-title">{title}</div>
          <button className="modal-x" type="button" onClick={onCancel} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>

        <div className="modal-body" style={{ paddingBottom: '8px' }}>
          <p style={{ margin: 0, color: '#374151', lineHeight: '1.5' }}>{message}</p>
        </div>

        <div className="modal-foot">
          <button className="btn-ghost" type="button" onClick={onCancel}>
            Annuler
          </button>
          <button
            className="btn-primary"
            type="button"
            style={{ background: '#ef4444' }}
            onClick={onConfirm}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}
