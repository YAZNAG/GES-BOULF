import { Download, Filter, UserPlus } from 'lucide-react'
import { useOutletContext } from 'react-router-dom'
import { CSVLink } from 'react-csv'
import Alert from '../../components/Alert'
import '../../styles/users.css'
import { useUtilisateursPage } from '../../features/utilisateurs/useUtilisateursPage'
import { UserModal } from '../../components/Utilisateurs/UserModal'
import { ViewUtilisateurs } from '../../components/Utilisateurs/ViewUtilisateurs'
import { ConfirmModal } from '../../components/ConfirmModal'

export default function Utilisateurs({ fixedRole }) {
  const outlet = useOutletContext() || {}
  const search = (outlet.search || outlet.searchQuery || '').toString()
  const setSearch = outlet.setSearch || outlet.setSearchQuery

  const {
    hasPermission,
    hasAnyPermission,
    loading,
    error,
    submitting,
    filteredUsers,
    allowedRoles,
    roleFilter,
    setRoleFilter,
    statusFilter,
    setStatusFilter,
    open,
    setOpen,
    modalMode,
    editing,
    setEditing,
    confirmOpen,
    setConfirmOpen,
    deleting,
    setDeleting,
    csvData,
    statsByUserId,
    openCreate,
    openEdit,
    askDelete,
    submit,
    confirmDelete,
    toggleActive,
  } = useUtilisateursPage(fixedRole, search, setSearch)

  if (!hasAnyPermission(['utilisateurs.view', 'utilisateurs.manage'])) {
    return (
      <section className="content users">
        <div className="users-empty">Accès refusé.</div>
      </section>
    )
  }

  const pageTitle = fixedRole === 'agent' ? 'Agents' : 'Utilisateurs'
  const pageSub = fixedRole ? 'Gestion des comptes' : 'Gestion des agents'

  return (
    <section className="content users">
      <div className="users-head">
        <div>
          <div className="users-title">{pageTitle}</div>
          <div className="users-subtitle">{pageSub}</div>
        </div>
        <div className="users-head-actions">
          <button className="users-add" type="button" onClick={openCreate} disabled={submitting || !hasPermission('utilisateurs.manage')}>
            <UserPlus size={18} />
            Ajouter Utilisateur
          </button>
        </div>
      </div>

      <Alert type="error" message={error} />

      <div className="users-bar">
        {!fixedRole ? (
          <div className="users-tabs">
            <button className={roleFilter === 'agent' ? 'users-tab users-tab-active' : 'users-tab'} type="button" onClick={() => setRoleFilter('agent')}>
              Agents
            </button>
            <button className={roleFilter === 'all' ? 'users-tab users-tab-active' : 'users-tab'} type="button" onClick={() => setRoleFilter('all')}>
              Tous
            </button>
          </div>
        ) : null}

        <div className="users-tools">
          <div className="users-searchbox">
            <input
              className="users-search-input"
              placeholder="Rechercher des utilisateurs…"
              value={search}
              onChange={(e) => (setSearch ? setSearch(e.target.value) : null)}
            />
          </div>

          <div className="users-tool-btns">
            <div className="users-filter">
              <Filter size={16} />
              <select className="users-filter-select" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
                <option value="all">Tous</option>
                <option value="actif">Actif</option>
                <option value="inactif">Inactif</option>
              </select>
            </div>

            <CSVLink className="users-export" data={csvData} filename="utilisateurs.csv">
              <Download size={16} />
              Exporter
            </CSVLink>
          </div>
        </div>
      </div>

      <div className="users-table">
        {loading ? <div className="users-empty">Loading…</div> : null}
        {!loading ? (
          <ViewUtilisateurs
            filteredUsers={filteredUsers}
            statsByUserId={statsByUserId}
            toggleActive={toggleActive}
            openEdit={openEdit}
            askDelete={askDelete}
            submitting={submitting}
            hasPermission={hasPermission}
          />
        ) : null}
      </div>

      <UserModal
        key={`${modalMode}-${open ? '1' : '0'}-${editing?.id || 'new'}`}
        open={open}
        mode={modalMode}
        roles={allowedRoles}
        initialValues={editing}
        onClose={() => {
          if (submitting) return
          setOpen(false)
          setEditing(null)
        }}
        onSubmit={submit}
      />

      <ConfirmModal
        open={confirmOpen}
        title="Supprimer"
        description={`Supprimer "${deleting?.nom || ''} ${deleting?.prenom || ''}" ?`}
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

