import { X } from "lucide-react"

export const EditModal = (props)=>{


    return(<div className="modal-overlay">
          <div className="modal">
            <div className="modal-head">
              <div className="modal-title">
                Modifier la commande{" "}
                {props.selectedCommande.numero || `#ORD-${props.selectedCommande.id}`}
              </div>
              <button
                className="modal-x"
                type="button"
                onClick={() => props.setEditModalOpen(false)}
                aria-label="Fermer"
              >
                <X size={20} />
              </button>
            </div>
            <div className="modal-body">
              <label className="form-label">
                Client
                <select
                  className="form-select"
                  value={props.editForm.client_id}
                  onChange={(e) =>
                    props.setEditForm({ ...props.editForm, client_id: e.target.value })
                  }
                >
                  <option value="">Sélectionner un client</option>
                  {props.clients.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.nom}
                    </option>
                  ))}
                </select>
              </label>

              <label className="form-label">
                Type
                <select
                  className="form-select"
                  value={props.editForm.type_commande}
                  onChange={(e) =>
                    props.setEditForm({ ...props.editForm, type_commande: e.target.value })
                  }
                >
                  <option value="livraison">Livraison</option>
                  <option value="retrait">Retrait</option>
                </select>
              </label>

              <label className="form-label">
                Statut
                <select
                  className="form-select"
                  value={props.editForm.statut}
                  onChange={(e) =>
                    props.setEditForm({ ...props.editForm, statut: e.target.value })
                  }
                >
                  <option value="en_attente">En cours</option>
                  <option value="confirmée">Confirmée</option>
                  <option value="payée">Payée</option>
                  <option value="annulée">Annulée</option>
                </select>
              </label>

              <label className="form-label">
                Total (MAD)
                <input
                  type="number"
                  className="form-input"
                  value={props.editForm.total}
                  onChange={(e) =>
                    props.setEditForm({ ...props.editForm, total: e.target.value })
                  }
                />
              </label>
            </div>
            <div className="modal-foot">
              <button
                className="btn-ghost"
                type="button"
                onClick={() => props.setEditModalOpen(false)}
              >
                Annuler
              </button>
              <button
                className="btn-primary"
                type="button"
                onClick={props.submitEdit}
              >
                Enregistrer
              </button>
            </div>
          </div>
        </div>)
}