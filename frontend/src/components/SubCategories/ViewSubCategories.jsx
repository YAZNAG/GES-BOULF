import { useNavigate, useParams } from 'react-router-dom'
import { Trash2 } from 'lucide-react'

export function ViewSubCategories({ subCategories, deleteSub, totals }) {
  const navigate = useNavigate()
  const { categoryId } = useParams()

  return (
    <>
      <div className="cat-grid">
        {subCategories.map((s) => (
          <div
            key={s.id}
            className="cat-card"
            onClick={() => navigate(`/admin/categories/${categoryId}/sub/${s.id}`)}
            role="button"
            tabIndex={0}
          >
            <div className="cat-top">
              <div className="cat-ico">
                {s.image ? <img className="cat-img" src={s.image} alt={s.nom} /> : <div className="cat-img-fallback">{(s.nom || '?')[0]}</div>}
              </div>
              <div>
                <div className="cat-name">{s.nom}</div>
                {(s.name_ar || s.name_fr) && (
                  <div style={{ fontSize: '11px', color: '#64748b' }}>
                    {s.name_fr} {s.name_ar && `| ${s.name_ar}`}
                  </div>
                )}
              </div>
            </div>
            <div className="cat-actions" onClick={(e) => e.stopPropagation()}>
              <button
                className="cat-icon-btn cat-icon-btn-danger"
                type="button"
                onClick={() => deleteSub(s)}
                aria-label="Supprimer"
              >
                <Trash2 size={16} />
              </button>
            </div>
          </div>
        ))}
      </div>

      <div className="cat-stats">
        <div>
          <div className="cat-stats-label">Total catégories</div>
          <div className="cat-stats-value">{totals.totalSous}</div>
        </div>
        <div className="cat-stats-right">
          <div className="cat-stats-label">Total Produits</div>
          <div className="cat-stats-value">{totals.totalProduits}</div>
        </div>
      </div>
    </>
  )
}
