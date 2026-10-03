import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { apiFetch } from '../../lib/api'
import ProductCard from '../../components/products/ProductCard'
import Alert from '../../components/Alert'
import '../../styles/categories.css'
import '../../styles/produits.css'

export default function CategoryProducts() {
  const { categoryId, subCategoryId } = useParams()
  const [products, setProducts] = useState([])
  const [category, setCategory] = useState(null)
  const [subCategory, setSubCategory] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    async function load() {
      setLoading(true)
      setError('')
      try {
        const [catRes, subRes, articlesRes] = await Promise.all([
          apiFetch(`/api/categories/${categoryId}`),
          apiFetch(`/api/sous_categories/${subCategoryId}`),
          apiFetch(`/api/articles?per_page=1000`)
        ])

        setCategory(catRes.data)
        setSubCategory(subRes.data)

        const allArticles = Array.isArray(articlesRes?.data) ? articlesRes.data : articlesRes?.data?.data || []
        
        // Filter articles by subCategoryId and map to display format
        const filtered = allArticles
          .filter(a => String(a.sous_categorie_id) === String(subCategoryId))
          .map(a => ({
            id: a.id,
            nom: a.nom,
            img: a.image || '/imagelogin.png',
            prix: a.prix?.prix_vente || 0,
            unite: a.unite || 'pièce',
            stock: a.stock?.quantite || 0,
            categoryName: catRes.data?.nom,
            subCategoryName: subRes.data?.nom
          }))

        setProducts(filtered)
      } catch (e) {
        setError(e.message || 'Erreur lors du chargement des produits')
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [categoryId, subCategoryId])

  return (
    <section className="content">
      <div className="breadcrumb">
        <Link className="breadcrumb-link" to="/admin/categories">
          Famille de Catégories
        </Link>
        <span className="breadcrumb-sep">/</span>
        <Link className="breadcrumb-link" to={`/admin/categories/${categoryId}`}>
          {category?.nom || 'Catégories'}
        </Link>
        <span className="breadcrumb-sep">/</span>
        <span className="breadcrumb-current">{subCategory?.nom || 'Produits'}</span>
      </div>

      <div className="page-head">
        <div>
          <div className="page-title">{subCategory?.nom || 'Produits'}</div>
          <div className="page-subtitle">
            {products.length} produits dans cette catégorie
          </div>
        </div>
      </div>

      <Alert type="error" message={error} />

      {loading ? (
        <div className="products-empty">Chargement des produits…</div>
      ) : products.length === 0 ? (
        <div className="products-empty">Aucun produit trouvé dans cette catégorie.</div>
      ) : (
        <div className="grid">
          {products.map(p => (
            <ProductCard key={p.id} product={p} />
          ))}
        </div>
      )}
    </section>
  )
}
