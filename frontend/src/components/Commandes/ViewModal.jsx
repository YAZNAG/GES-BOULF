import { X } from "lucide-react"

export const ViewModal = (props)=>{
    return(   <div className="modal-overlay">
          <div className="modal modal-red">
            <div className="modal-head">
              <div className="modal-title">
                Détails de la commande{" "}
                {props.selectedCommande.numero || `#ORD-${props.selectedCommande.id}`}
              </div>
              <button
                className="modal-x modal-x-invert"
                type="button"
                onClick={() => props.setViewModalOpen(false)}
                aria-label="Fermer"
              >
                <X size={20} />
              </button>
            </div>
            <div className="modal-body modal-body-red">
              <div>
                <div className="detail-label">Client</div>
                <div className="detail-value detail-strong">
                  {props.selectedCommande.client
                    ?props. selectedCommande.client.nom
                    : "Client inconnu"}
                </div>
              </div>

              <div>
                <div className="detail-label">Articles</div>
                <div className="detail-list">
                  {props.selectedCommande.lignes &&
                  props.selectedCommande.lignes.length > 0 ? (
                    props.selectedCommande.lignes.map((ligne, idx) => (
                      <div key={idx} className="detail-list-item">
                        {ligne.article ? ligne.article.nom : "Article"} (
                        {ligne.quantite}{" "}
                        {ligne.article ? ligne.article.unite : ""})
                      </div>
                    ))
                  ) : (
                    <div className="detail-list-item">
                      Aucun article enregistré.
                    </div>
                  )}
                </div>
              </div>

              <div className="detail-total">
                <span>Total</span>
                <span className="detail-strong">
                  {props.selectedCommande.total} MAD
                </span>
              </div>
            </div>
          </div>
        </div>)

}