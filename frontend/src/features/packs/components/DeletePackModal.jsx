import { X } from 'lucide-react'

export default function DeletePackModal({ open, packName, submitting, onClose, onConfirm }) {
  if (!open) return null

  return (
    <div className="modal-overlay" onMouseDown={onClose}>
      <div className="modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-title">Supprimer le pack</div>
          <button className="modal-x" type="button" onClick={onClose} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>
        <div className="modal-body">
          <div className="form-label">{`Voulez-vous supprimer "${packName || ''}" ?`}</div>
          <div className="modal-foot">
            <button className="btn-ghost" type="button" onClick={onClose} disabled={submitting}>
              Annuler
            </button>
            <button className="btn-danger" type="button" onClick={onConfirm} disabled={submitting}>
              Supprimer
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

