import { useMemo } from 'react'

function safeStr(v) {
  return (v == null ? '' : String(v)).trim()
}

export default function ProductDetails({ article }) {
  const image = useMemo(() => {
    const v = safeStr(article?.image) || safeStr(article?.img)
    return v || '/imagelogin.png'
  }, [article])

  const nom = safeStr(article?.nom)
  const code = safeStr(article?.code_article)
  const unite = safeStr(article?.unite) || 'pièce'
  const actif = !!article?.actif

  const sousCat = safeStr(article?.sous_categorie?.nom || article?.sousCategorie?.nom)
  const cat = safeStr(article?.sous_categorie?.categorie?.nom || article?.sousCategorie?.categorie?.nom)

  const prixVente = article?.prix?.prix_vente ?? article?.prix_vente ?? null
  const stock = article?.stock?.quantite ?? article?.stock ?? null
  const seuilMin = article?.stock?.seuil_min ?? article?.seuil_min ?? null

  return (
    <div className="pdetails">
      <div className="pdetails-left">
        <div className="pdetails-img">
          <img src={image} alt="" />
        </div>
      </div>

      <div className="pdetails-right">
        <div className="pdetails-title">{nom || '—'}</div>
        <div className="pdetails-sub">
          <span>{code ? `Code: ${code}` : '—'}</span>
          <span>•</span>
          <span>{actif ? 'Actif' : 'Inactif'}</span>
        </div>

        <div className="pdetails-grid">
          <div className="pdetails-item">
            <div className="pdetails-label">Catégorie</div>
            <div className="pdetails-value">{cat || '—'}</div>
          </div>
          <div className="pdetails-item">
            <div className="pdetails-label">Sous-catégorie</div>
            <div className="pdetails-value">{sousCat || '—'}</div>
          </div>
          <div className="pdetails-item">
            <div className="pdetails-label">Unité</div>
            <div className="pdetails-value">{unite}</div>
          </div>
          <div className="pdetails-item">
            <div className="pdetails-label">Prix vente</div>
            <div className="pdetails-value">{prixVente != null ? `${Number(prixVente)} DH` : '—'}</div>
          </div>
          <div className="pdetails-item">
            <div className="pdetails-label">Stock actuel</div>
            <div className="pdetails-value">{stock != null ? `${Number(stock)} ${unite}` : '—'}</div>
          </div>
          <div className="pdetails-item">
            <div className="pdetails-label">Stock minimal</div>
            <div className="pdetails-value">{seuilMin != null ? `${Number(seuilMin)} ${unite}` : '—'}</div>
          </div>
        </div>

        {safeStr(article?.description) ? <div className="pdetails-desc">{safeStr(article?.description)}</div> : null}
      </div>
    </div>
  )
}
