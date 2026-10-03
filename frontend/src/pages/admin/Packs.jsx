import { Plus, MessageCircle, Edit2, Trash2, Search } from 'lucide-react'
import { useOutletContext } from 'react-router-dom'
import Alert from '../../components/Alert'
import { useAuth } from '../../auth/authContext'
import PackModal from '../../features/packs/components/PackModal'
import DeletePackModal from '../../features/packs/components/DeletePackModal'
import { usePacksPage } from '../../features/packs/usePacksPage'
import '../../styles/packs.css'

export default function Packs() {
  const { hasAnyPermission } = useAuth()
  const outlet = useOutletContext() || {}
  const search = (outlet.search || '').toString()
  const setSearch = outlet.setSearch

  const enabled = hasAnyPermission(['packs.view', 'packs.manage', 'systeme.settings'])
  const canManage = hasAnyPermission(['packs.manage', 'systeme.settings'])

  const {
    loading,
    error,
    articles,
    open,
    modalMode,
    editing,
    confirmOpen,
    deleting,
    submitting,
    filtered,
    setOpen,
    setConfirmOpen,
    setDeleting,
    openCreate,
    openEdit,
    askDelete,
    submit,
    confirmDelete,
    togglePackStatus,
  } = usePacksPage({ search, enabled })

  const shareWhatsApp = (p) => {
    const text = `🌟 *Offre Spéciale : ${p.nom}* 🌟\n\n💰 Prix : *${p.prix_vente} DH*\n📦 Contenu : ${p.items?.length} produits\n\nIntéressé ? Contactez-nous !`
    window.open(`https://wa.me/?text=${encodeURIComponent(text)}`, '_blank')
  }

  if (!enabled) {
    return (
      <section className="content">
        <div className="products-empty">Accès refusé.</div>
      </section>
    )
  }

  return (
    <section className="content packs">
      <div className="page-head">
        <div>
          <h1 className="page-title">Packs</h1>
          <p className="page-subtitle">Créez des packs promotionnels et gérez les produits inclus</p>
        </div>
        <button
          className="primary primary-pill"
          type="button"
          onClick={openCreate}
          disabled={submitting || !canManage}
        >
          <Plus size={18} />
          Nouveau pack
        </button>
      </div>

      <Alert type="error" message={error} />

      <div className="packs-toolbar">
        <div className="packs-search-box">
          <Search size={18} className="search-ico-bg" /> 
          <input
            className="packs-search-input"
            placeholder="Rechercher un pack…"
            value={search}
            onChange={(e) => (setSearch ? setSearch(e.target.value) : null)}
          />
        </div>
      </div>

      <div className="packs-wrap">
        {loading ? <div className="loading-state"><div className="spinner" /></div> : null}
        {!loading ? (
          <div className="packs-grid">
            {filtered.map((p) => (
              <div key={p.id} className="packs-card">
                <div className="packs-card-header">
                  <div className="packs-card-title">{p.nom}</div>
                  <button 
                    className="packs-share-btn" 
                    onClick={() => shareWhatsApp(p)}
                    title="Partager sur WhatsApp"
                  >
                    <MessageCircle size={18} color="#25D366" />
                  </button>
                </div>
                <div className="packs-card-sub">{Array.isArray(p.items) ? `${p.items.length} produits inclus` : '—'}</div>
                <div className="packs-card-price">{Number(p.prix_vente || 0).toLocaleString('fr-FR')} DH</div>
                
                <div className="packs-card-status">
                  <span className="info-label">Statut</span>
                  <label className="toggle-switch">
                    <input 
                      type="checkbox" 
                      checked={!!p.actif} 
                      onChange={() => togglePackStatus(p)}
                      disabled={!canManage}
                    />
                    <span className="toggle-slider"></span>
                  </label>
                  <span className={p.actif ? 'status-text active' : 'status-text'}>
                    {p.actif ? 'Actif' : 'Inactif'}
                  </span>
                </div>

                <div className="packs-card-foot">
                  <div className="packs-actions">
                    <button
                      className="btn-icon"
                      type="button"
                      onClick={() => openEdit(p)}
                      disabled={!canManage}
                      title="Modifier"
                    >
                      <Edit2 size={16} />
                    </button>
                    <button
                      className="btn-icon btn-danger"
                      type="button"
                      onClick={() => askDelete(p)}
                      disabled={!canManage}
                      title="Supprimer"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                </div>
              </div>
            ))}

            {filtered.length === 0 ? <div className="empty-state">Aucun pack trouvé</div> : null}
          </div>
        ) : null}
      </div>

      <PackModal
        key={`${modalMode}-${open ? '1' : '0'}-${editing?.id || 'new'}`}
        open={open}
        mode={modalMode}
        initialValues={modalMode === 'edit' ? editing : null}
        articles={articles}
        onClose={() => (submitting ? null : setOpen(false))}
        onSubmit={submit}
      />

      <DeletePackModal
        open={confirmOpen}
        packName={deleting?.nom || ''}
        submitting={submitting}
        onClose={() => {
          setConfirmOpen(false)
          setDeleting(null)
        }}
        onConfirm={confirmDelete}
      />
    </section>
  )
}
