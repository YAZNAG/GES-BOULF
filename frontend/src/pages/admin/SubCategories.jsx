import { Link, useParams } from 'react-router-dom'
import { Plus } from 'lucide-react'
import Alert from '../../components/Alert'
import '../../styles/categories.css'
import { useSubCategoriesPage } from '../../features/subcategories/useSubCategoriesPage'
import { SubCategoryModal } from '../../components/SubCategories/SubCategoryModal'
import { ViewSubCategories } from '../../components/SubCategories/ViewSubCategories'

export default function SubCategories() {
  const { categoryId } = useParams()
  const {
    open,
    setOpen,
    category,
    subCategories,
    totals,
    loading,
    error,
    addSub,
    deleteSub,
  } = useSubCategoriesPage(categoryId)

  return (
    <section className="content">
      <div className="breadcrumb">
        <Link className="breadcrumb-link" to="/admin/categories">
          Famille de Catégories
        </Link>
        <span className="breadcrumb-sep">/</span>
        <span className="breadcrumb-current">Catégories</span>
      </div>

      <div className="page-head">
        <div>
          <div className="page-title">Catégories</div>
          <div className="page-subtitle">{category?.nom ? `Catégorie: ${category.nom}` : `Catégorie ID: ${categoryId}`}</div>
        </div>
        <button className="primary primary-pill" type="button" onClick={() => setOpen(true)}>
          <Plus size={16} />
          Ajouter Catégorie
        </button>
      </div>

      <Alert type="error" message={error} />
      
      {loading ? (
        <div className="products-empty">Loading…</div>
      ) : (
        <ViewSubCategories subCategories={subCategories} deleteSub={deleteSub} totals={totals} />
      )}

      <SubCategoryModal open={open} onClose={() => setOpen(false)} onSubmit={addSub} />
    </section>
  )
}

