import { Plus, Search } from 'lucide-react'
import { useOutletContext } from 'react-router-dom'
import { CSVLink } from 'react-csv'
import Alert from '../../components/Alert'
import '../../styles/clients.css'
import { useClientsPage } from '../../features/clients/useClientsPage'
import { ClientModal } from '../../components/Clients/ClientModal'
import { ViewClients } from '../../components/Clients/ViewClients'
import { PaymentModal } from '../../components/Clients/PaymentModal'
import { ClientHistoryModal } from '../../components/Clients/ClientHistoryModal'
import { ConfirmModal } from '../../components/ConfirmModal'

export default function Clients() {
  const outlet = useOutletContext() || {}
  const search = (outlet.search || '').toString()
  const setSearch = typeof outlet.setSearch === 'function' ? outlet.setSearch : () => {}

  const {
    loading,
    error,
    open,
    setOpen,
    confirmOpen,
    setConfirmOpen,
    editing,
    deleting,
    setDeleting,
    submitting,
    typeFilter,
    setTypeFilter,
    filtered,
    openAdd,
    openEdit,
    openDelete,
    openPayment,
    paymentOpen,
    setPaymentOpen,
    payingClient,
    openHistory,
    historyOpen,
    setHistoryOpen,
    historyClient,
    clientHistory,
    submit,
    submitPayment,
    confirmDelete
  } = useClientsPage(search)

  return (
    <section className="content">
      <div className="page-head">
        <div>
          <div className="page-title">Clients</div>
          <div className="page-subtitle">Gestion des clients et de leurs soldes</div>
        </div>
        <button className="primary primary-pill" type="button" onClick={openAdd} disabled={loading}>
          <Plus size={16} />
          Ajouter
        </button>
      </div>

      <div className="toolbar">
        <div className="toolbar-left">
          <div className="tool-search">
            <Search size={16} color="#94a3b8" />
            <input
              className="tool-search-input"
              placeholder="Rechercher un client (nom, téléphone, email)…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <select className="tool-select" value={typeFilter} onChange={(e) => setTypeFilter(e.target.value)}>
            <option value="all">Tous les types</option>
            <option value="detail">Détail</option>
            <option value="gros">Gros</option>
          </select>
        </div>
        <div className="toolbar-right">
          <button className="btn-ghost" type="button">
             <CSVLink data={filtered} filename="clients.csv" style={{color:'red',textDecoration:'none'}}>
                          Exporter CSV
             </CSVLink>
          </button>
        </div>
      </div>

      <Alert type="error" message={error} />

      <div className="clients-card">
        <div className="clients-card-head">
          <div className="clients-card-title">Liste des clients ({filtered.length})</div>
        </div>

        {loading ? (
          <div className="clients-empty">Loading…</div>
        ) : (
          <ViewClients 
            filtered={filtered} 
            openEdit={openEdit} 
            openDelete={openDelete} 
            openPayment={openPayment}
            openHistory={openHistory}
          />
        )}
      </div>

      <ClientModal
        key={`${open ? '1' : '0'}-${editing?.id || 'new'}`}
        open={open}
        editing={editing}
        onClose={() => setOpen(false)}
        onSubmit={submit}
        submitting={submitting}
      />

      <PaymentModal
        key={`${paymentOpen ? '1' : '0'}-${payingClient?.id || 'none'}`}
        open={paymentOpen}
        client={payingClient}
        onClose={() => setPaymentOpen(false)}
        onSubmit={submitPayment}
        submitting={submitting}
      />

      <ClientHistoryModal
        open={historyOpen}
        client={historyClient}
        history={clientHistory}
        onClose={() => setHistoryOpen(false)}
      />

      <ConfirmModal
        open={confirmOpen}
        title="Supprimer ?"
        description={`Cette action est irréversible. Cela supprimera définitivement le client "${deleting?.nom || ''}".`}
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

