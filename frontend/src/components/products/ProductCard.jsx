import { Eye, Pencil, Trash2 } from 'lucide-react'

export default function ProductCard({ product, onDetails, onEdit, onDelete }) {
  return (
    <div className="card">
      <div className="card-badge">
        {product.poids ? `${product.poids} ${product.unite}` : product.unite} 
      </div>
      <div className="card-img">
        <img src={product.img} alt="" />
      </div>
      <div className="card-body">
        <div className="card-name">
          {product.nom}
          {(product.name_ar || product.name_fr) && (
            <div style={{ fontSize: '12px', color: '#64748b', fontWeight: 'normal' }}>
              {product.name_fr} {product.name_ar && `| ${product.name_ar}`}
            </div>
          )}
        </div>
        <div className="card-cat">
          {product.categoryName ? `${product.categoryName} / ` : ''}
          {product.subCategoryName || product.categorie}
          {product.marqueName && (
            <div style={{ color: '#0f766e', fontWeight: 'bold', fontSize: '11px', marginTop: '2px' }}>
              {product.marqueName}
            </div>
          )}
          {Number.isFinite(product.stock) ? <div style={{ marginTop: '2px' }}>{product.stock} unités en stock</div> : ''}
        </div>
        <div className="card-foot">
          <div className="card-price">
            {product.prix} DH/{product.unite}
          </div>
          {(onDetails || onEdit || onDelete) && (
            <div className="card-actions">
              {onDetails && (
                <button className="mini" type="button" aria-label="Details" onClick={() => onDetails(product)}>
                  <Eye size={16} color="#64748b" />
                </button>
              )}
              {onEdit && (
                <button className="mini" type="button" aria-label="Edit" onClick={() => onEdit(product)}>
                  <Pencil size={16} color="#64748b" />
                </button>
              )}
              {onDelete && (
                <button className="mini mini-danger" type="button" aria-label="Delete" onClick={() => onDelete(product)}>
                  <Trash2 size={16} color="#ef4444" />
                </button>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
