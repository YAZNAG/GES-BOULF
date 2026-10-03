import { Eye, Pencil, Trash2 } from 'lucide-react'

export default function ProductRow({ product, onDetails, onEdit, onDelete }) {
  return (
    <div className="product-row">
      <div className="product-left">
        <div className="product-thumb">
          <img src={product.img} alt="" />
        </div>
        <div className="product-info">
          <div className="product-name">
            {product.nom}
            {(product.name_ar || product.name_fr) && (
              <div style={{ fontSize: '13px', color: '#64748b', fontWeight: 'normal' }}>
                {product.name_fr} {product.name_ar && `| ${product.name_ar}`}
              </div>
            )}
          </div>
          <div className="product-meta">
            {product.categoryName ? `${product.categoryName} / ` : ''}
            {product.subCategoryName || product.categorie}
            {product.marqueName && (
              <>
                <br />
                <span style={{ color: '#0f766e', fontWeight: 'bold' }}>{product.marqueName}</span>
              </>
            )}
            <br />
            {product?.code_article}
          </div>
        </div>
      </div>

      <div className="product-mid">
        <div className="product-price">{product.prix} MAD</div>
        <div className="product-stock">{product.stock} unités</div>
      </div>

      <div className="product-actions">
        <button className="icon-pill" type="button" onClick={() => onDetails?.(product)} aria-label="Détails">
          <Eye size={18} />
        </button>
        <button className="icon-pill" type="button" onClick={() => onEdit?.(product)} aria-label="Modifier">
          <Pencil size={18} />
        </button>
        <button className="icon-pill icon-pill-danger" type="button" onClick={() => onDelete?.(product)} aria-label="Supprimer">
          <Trash2 size={18} />
        </button>
      </div>
    </div>
  )
}
