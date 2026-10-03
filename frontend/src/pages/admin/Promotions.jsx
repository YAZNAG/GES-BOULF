import { Plus } from 'lucide-react'
import Alert from '../../components/Alert'
import '../../styles/promotions.css'
import { usePromotionsPage } from '../../features/promotions/usePromotionsPage'
import { PromoModal } from '../../components/Promotions/PromoModal'
import { ConfirmModal } from '../../components/ConfirmModal'
import { PromoTabs } from '../../components/Promotions/PromoTabs'
import { ViewPromotions } from '../../components/Promotions/ViewPromotions'

export default function Promotions() {
  const {
    tab,
    setTab,
    loading,
    error,
    modalOpen,
    setModalOpen,
    editing,
    confirmOpen,
    setConfirmOpen,
    deleting,
    targets,
    visible,
    openCreate,
    openEdit,
    openDelete,
    savePromotion,
    confirmDelete,
    togglePromotionStatus,
  } = usePromotionsPage()

  return (
    <section className="content">
      <div className="page-head">
        <div>
          <h1 className="page-title">Promotions </h1>
          <p className="page-subtitle">Gérez les offres spéciales et les codes promotionnels</p>
        </div>
        <button className="primary primary-pill" type="button" onClick={openCreate}>
          <Plus size={18} />
          Créer Promotion
        </button>
      </div>

      <PromoTabs tab={tab} setTab={setTab} />

      <Alert type="error" message={error} />

      {loading ? (
        <div className="loading-state"><div className="spinner" /></div>
      ) : (
        <ViewPromotions 
          visible={visible} 
          openEdit={openEdit} 
          openDelete={openDelete} 
          toggleStatus={togglePromotionStatus}
        />
      )}

      <PromoModal
        key={`${modalOpen ? '1' : '0'}-${editing?.id || 'new'}`}
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        onSubmit={savePromotion}
        initial={editing}
        targets={targets}
      />

      <ConfirmModal
        open={confirmOpen}
        onClose={() => setConfirmOpen(false)}
        onConfirm={confirmDelete}
        title="Êtes-vous sûr ?"
        description={
          deleting ? `Cette action est irréversible. Cela supprimera définitivement la promotion "${deleting.name}".` : ''
        }
        confirmLabel="Supprimer"
      />
    </section>
  )
}
