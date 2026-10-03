import { Plus, Search } from "lucide-react";
import { useOutletContext } from "react-router-dom";
import { CSVLink } from "react-csv";

import Alert from "../../components/Alert";
import "../../styles/fournisseurs.css";
import { useFournisseursPage } from "../../features/fournisseurs/useFournisseursPage";
import { FournisseurModal } from "../../components/Fournisseurs/FournisseurModal";
import { ViewFournisseurs } from "../../components/Fournisseurs/ViewFournisseurs";
import { ConfirmModal } from "../../components/ConfirmModal";

export default function Fournisseurs() {
  const outlet = useOutletContext() || {};
  const search = (outlet.search || "").toString();
  const setSearch =
    typeof outlet.setSearch === "function" ? outlet.setSearch : () => {};

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
    filtered,
    openAdd,
    openEdit,
    openDelete,
    submit,
    confirmDelete
  } = useFournisseursPage(search)

  return (
    <section className="content">
      <div className="page-head">
        <div>
          <div className="page-title">Fournisseurs</div>
          <div className="page-subtitle">Gestion des fournisseurs</div>
        </div>
        <button
          className="primary primary-pill"
          type="button"
          onClick={openAdd}
          disabled={loading}
        >
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
              placeholder="Rechercher un fournisseur (nom, téléphone, email)…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
        </div>
        <div className="toolbar-right">
          <button className="btn-ghost" type="button">
            <CSVLink data={filtered} filename="fournisseurs.csv" style={{color:'red',textDecoration:'none'}}>
              Exporter CSV
            </CSVLink>
          </button>
        </div>
      </div>

      <Alert type="error" message={error} />

      <div className="fournisseurs-card">
        <div className="fournisseurs-card-head">
          <div className="fournisseurs-card-title">
            Liste des fournisseurs ({filtered.length})
          </div>
        </div>

        {loading ? (
          <div className="fournisseurs-empty">Loading…</div>
        ) : (
          <ViewFournisseurs filtered={filtered} openEdit={openEdit} openDelete={openDelete} />
        )}
      </div>

      <FournisseurModal
        key={`${open ? '1' : '0'}-${editing?.id || 'new'}`}
        open={open}
        editing={editing}
        onClose={() => setOpen(false)}
        onSubmit={submit}
        submitting={submitting}
      />

      <ConfirmModal
        open={confirmOpen}
        title="Supprimer ?"
        description={`Cette action est irréversible. Cela supprimera définitivement le fournisseur "${deleting?.nom || ''}".`}
        onClose={() => {
          setConfirmOpen(false)
          setDeleting(null)
        }}
        onConfirm={confirmDelete}
        confirmLabel="Supprimer"
        disabled={submitting}
      />
    </section>
  );
}

