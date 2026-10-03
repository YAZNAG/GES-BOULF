import { Plus } from 'lucide-react'
import Alert from '../../components/Alert'
import '../../styles/role.css'
import { useRolesPage } from '../../features/roles/useRolesPage'
import { RoleModal } from '../../components/Roles/RoleModal'
import { ViewRoles } from '../../components/Roles/ViewRoles'
import { ConfirmModal } from '../../components/ConfirmModal'

export default function Roles() {
  const {
    hasPermission,
    loading,
    error,
    open,
    setOpen,
    modalMode,
    editing,
    setEditing,
    confirmOpen,
    setConfirmOpen,
    deleting,
    setDeleting,
    submitting,
    modalSeed,
    roleCards,
    openCreate,
    openEdit,
    askDelete,
    submit,
    confirmDelete
  } = useRolesPage()

  if (!hasPermission('systeme.settings')) {
    return (
      <section className="content roles">
        <div className="roles-empty">Accès refusé.</div>
      </section>
    )
  }

  return (
    <section className="content roles">
      <div className="page-head roles-head">
        <div>
          <div className="page-title">Rôles &amp; Permissions</div>
          <div className="page-subtitle">Gérer les rôles et leurs permissions</div>
        </div>
        <button className="primary primary-pill" type="button" onClick={openCreate}>
          <Plus size={16} />
          Créer Rôle
        </button>
      </div>

      {/* <Alert type="error" message={error} /> */}

      <div className="roles-layout">
        <div className="roles-main">
          {loading ? (
            <div className="roles-empty">Loading…</div>
          ) : (
            <ViewRoles roleCards={roleCards} openEdit={openEdit} askDelete={askDelete} />
          )}
        </div>
      </div>

      <RoleModal
        key={modalSeed}
        open={open}
        mode={modalMode}
        initialValues={modalMode === 'edit' ? editing : null}
        onClose={() => {
          if (submitting) return
          setOpen(false)
          setEditing(null)
        }}
        onSubmit={submit}
      />

      <ConfirmModal
        open={confirmOpen}
        title="Supprimer le rôle"
        description={`Voulez-vous supprimer "${deleting?.nom || ''}" ?`}
        onClose={() => {
          setConfirmOpen(false)
          setDeleting(null)
        }}
        onConfirm={confirmDelete}
        confirmLabel="Supprimer"
        disabled={submitting}
      />
    </section>
  )
}

