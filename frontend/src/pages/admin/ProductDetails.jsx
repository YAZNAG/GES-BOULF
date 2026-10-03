import { useEffect, useState } from 'react'
import { ArrowLeft } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { apiFetch } from '../../lib/api'
import Alert from '../../components/Alert'
import ProductDetailsView from '../../components/products/productdetails'
import '../../styles/product-details.css'

export default function ProductDetails() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [article, setArticle] = useState(null)

  useEffect(() => {
    async function load() {
      setLoading(true)
      setError('')
      try {
        const data = await apiFetch(`/api/articles/${id}`)
        setArticle(data)
      } catch (e) {
        setError(e?.message || 'Erreur')
      } finally {
        setLoading(false)
      }
    }
    if (id) load()
  }, [id])

  return (
    <section className="content">
      <div className="page-head">
        <div>
          <div className="page-title">Détails produit</div>
          <div className="page-subtitle">Consulter les informations du produit</div>
        </div>
        <button className="btn-ghost" type="button" onClick={() => navigate(-1)}>
          <ArrowLeft size={18} />
          Retour
        </button>
      </div>

      <Alert type="error" message={error} />

      {loading ? <div className="pdetails-skel">Loading…</div> : null}
      {!loading && article ? <ProductDetailsView article={article} /> : null}
    </section>
  )
}

