import { X } from "lucide-react"

export const DeleteModal=(props)=>{

    return(<div className="modal-overlay">
          <div className="modal">
            <div className="modal-head">
              <div className="modal-title">Êtes-vous sûr ?</div>
              <button
                className="modal-x"
                type="button"
                onClick={() => props.setDeleteModalOpen(false)}
                aria-label="Fermer"
              >
                <X size={20} />
              </button>
            </div>
            <div className="modal-body">
              <div className="orders-confirm-text">
                Cette action est irréversible. Cela supprimera définitivement la
                commande{" "}
                <span className="orders-confirm-strong">
                  {props.selectedCommande.numero || `#ORD-${props.selectedCommande.id}`}
                </span>
                .
              </div>
              <div className="modal-foot">
                <button
                  className="btn-ghost"
                  type="button"
                  onClick={() => props.setDeleteModalOpen(false)}
                >
                  Annuler
                </button>
                <button
                  className="btn-danger"
                  type="button"
                  onClick={props.confirmDelete}
                >
                  Supprimer
                </button>
              </div>
            </div>
          </div>
        </div>)
}