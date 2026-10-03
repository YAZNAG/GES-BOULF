import { useEffect, useMemo, useState } from "react";
import { Pencil, Plus, Search, X } from "lucide-react";
import { useOutletContext } from "react-router-dom";
import { apiFetch } from "../../lib/api";
import { CSVLink } from "react-csv";
import Alert from "../../components/Alert";
import "../../styles/prix.css";

export default function Prix() {
  const outlet = useOutletContext() || {};
  const search = (outlet.search || "").toString();
  const setSearch =
    typeof outlet.setSearch === "function" ? outlet.setSearch : () => {};

  const [articles, setArticles] = useState([]);
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [filter, setFilter] = useState("all");

  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState(null);
  const [creating, setCreating] = useState(false);

  const [form, setForm] = useState({
    article_id: "",
    prix_achat: 0,
    prix_vente: 0,
    prix_gros: "",
    prix_promo: "",
  });

  async function loadAll() {
    setLoading(true);
    setError("");
    try {
      const [articlesRes, prixRes] = await Promise.all([
        apiFetch("/api/articles?per_page=1000"),
        apiFetch("/api/prix_articles?per_page=1000"),
      ]);
      const a = Array.isArray(articlesRes?.data)
        ? articlesRes.data
        : articlesRes?.data?.data || [];
      const p = Array.isArray(prixRes?.data)
        ? prixRes.data
        : prixRes?.data?.data || [];
      setArticles(a);
      setItems(p);
    } catch (e) {
      setError(e?.message || "Erreur");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadAll();
  }, []);

  const prixByArticleId = useMemo(
    () => new Map(items.map((it) => [String(it.article_id), it])),
    [items],
  );

  const missingArticles = useMemo(() => {
    return articles.filter((a) => !prixByArticleId.has(String(a.id)));
  }, [articles, prixByArticleId]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return items.filter((p) => {
      const articleNom = (p?.article?.nom || "").toString().toLowerCase();
      const code = (p?.article?.code_article || "").toString().toLowerCase();
      const okQuery = !q ? true : articleNom.includes(q) || code.includes(q);
      const promo = p?.prix_promo != null && Number(p.prix_promo) > 0;
      const okFilter = filter === "all" ? true : promo;
      return okQuery && okFilter;
    });
  }, [items, search, filter]);

  function openCreate() {
    setCreating(true);
    setEditing(null);
    setForm({
      article_id: "",
      prix_achat: 0,
      prix_vente: 0,
      prix_gros: "",
      prix_promo: "",
    });
    setOpen(true);
  }

  function openEdit(row) {
    setCreating(false);
    setEditing(row);
    setForm({
      article_id: String(row?.article_id || ""),
      prix_achat: Number(row?.prix_achat ?? 0),
      prix_vente: Number(row?.prix_vente ?? 0),
      prix_gros: row?.prix_gros == null ? "" : Number(row.prix_gros),
      prix_promo: row?.prix_promo == null ? "" : Number(row.prix_promo),
    });
    setOpen(true);
  }

  async function submit(e) {
    e.preventDefault();
    setError("");
    try {
      const payload = {
        article_id: Number(form.article_id),
        prix_achat: Number(form.prix_achat),
        prix_vente: Number(form.prix_vente),
        prix_gros: form.prix_gros === "" ? null : Number(form.prix_gros),
        prix_promo: form.prix_promo === "" ? null : Number(form.prix_promo),
      };

      if (creating) {
        await apiFetch("/api/prix_articles", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
      } else if (editing?.id) {
        await apiFetch(`/api/prix_articles/${editing.id}`, {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            prix_achat: payload.prix_achat,
            prix_vente: payload.prix_vente,
            prix_gros: payload.prix_gros,
            prix_promo: payload.prix_promo,
          }),
        });
      }

      setOpen(false);
      await loadAll();
    } catch (e2) {
      setError(e2?.message || "Erreur");
    }
  }

  return (
    <section className="content">
      <div className="page-head">
        <div>
          <div className="page-title">Prix</div>
          <div className="page-subtitle">Gestion des prix des articles</div>
        </div>
        <button
          className="primary primary-pill"
          type="button"
          onClick={openCreate}
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
              placeholder="Rechercher (nom ou code)…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <select
            className="tool-select"
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
          >
            <option value="all">Tous</option>
            <option value="promo">Avec promo</option>
          </select>
        </div>
        <div className="toolbar-right">
          <button className="btn-ghost" type="button">
            <CSVLink
              data={filtered}
              filename="prix.csv"
              style={{ color: "red", textDecoration: "none" }}
            >
              Exporter CSV
            </CSVLink>
          </button>
        </div>
      </div>

      <Alert type="error" message={error} />

      <div className="prix-card">
        <div className="prix-card-head">
          <div className="prix-card-title">
            Liste des prix ({filtered.length})
          </div>
        </div>

        {loading ? (
          <div className="prix-empty">Loading…</div>
        ) : (
          <div className="prix-table-wrap">
            <table className="prix-table">
              <thead>
                <tr>
                  <th>id</th>
                  <th>Article</th>
                  <th>Achat</th>
                  <th>Vente</th>
                  <th>Gros</th>
                  <th>Promo</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((p) => {
                  const code = p?.article?.code_article
                    ? `(${p.article.code_article}) `
                    : "";
                  return (
                    <tr key={p.id}>
                       <td className="fw-500">
                        {p.id}
                      </td>
                      <td className="fw-500">
                        {code}
                        {p?.article?.nom || "—"}
                      </td>
                      <td>{Number(p.prix_achat ?? 0)} MAD</td>
                      <td>{Number(p.prix_vente ?? 0)} MAD</td>
                      <td>
                        {p.prix_gros == null
                          ? "—"
                          : `${Number(p.prix_gros)} MAD`}
                      </td>
                      <td>
                        {p.prix_promo == null
                          ? "—"
                          : `${Number(p.prix_promo)} MAD`}
                      </td>
                      <td>
                        <div className="prix-actions">
                          <button
                            className="icon-pill"
                            type="button"
                            onClick={() => openEdit(p)}
                            aria-label="Modifier"
                          >
                            <Pencil size={18} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan="6" className="prix-empty-cell">
                      Aucun prix
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {open ? (
        <div className="modal-overlay" onClick={() => setOpen(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <div className="modal-title">
                {creating ? "Ajouter un prix" : "Modifier le prix"}
              </div>
              <button
                className="modal-x"
                type="button"
                onClick={() => setOpen(false)}
                aria-label="Fermer"
              >
                <X size={18} />
              </button>
            </div>
            <form className="modal-body" onSubmit={submit}>
              <Alert type="error" message={error} />
              <label className="form-label">
                Article
                <select
                  className="form-select"
                  value={form.article_id}
                  onChange={(e) =>
                    setForm((p) => ({ ...p, article_id: e.target.value }))
                  }
                  disabled={!creating}
                  required
                >
                  <option value="">Sélectionner un article</option>
                  {creating && missingArticles.length === 0 && (
                    <option value="" disabled>Tous les articles ont déjà un prix</option>
                  )}
                  {(creating ? missingArticles : articles).map((a) => (
                    <option key={a.id} value={a.id}>
                      {a.code_article ? `${a.code_article} — ` : ""}
                      {a.nom}
                    </option>
                  ))}
                </select>
              </label>

              <div className="form-grid">
                <label className="form-label">
                  Prix achat
                  <input
                    className="form-input"
                    type="number"
                    step="0.01"
                    value={form.prix_achat}
                    onChange={(e) =>
                      setForm((p) => ({ ...p, prix_achat: e.target.value }))
                    }
                    required
                  />
                </label>

                <label className="form-label">
                  Prix vente
                  <input
                    className="form-input"
                    type="number"
                    step="0.01"
                    value={form.prix_vente}
                    onChange={(e) =>
                      setForm((p) => ({ ...p, prix_vente: e.target.value }))
                    }
                    required
                  />
                </label>
              </div>

              <div className="form-grid">
                <label className="form-label">
                  Prix gros (optionnel)
                  <input
                    className="form-input"
                    type="number"
                    step="0.01"
                    value={form.prix_gros}
                    onChange={(e) =>
                      setForm((p) => ({ ...p, prix_gros: e.target.value }))
                    }
                  />
                </label>

                <label className="form-label">
                  Prix promo (optionnel)
                  <input
                    className="form-input"
                    type="number"
                    step="0.01"
                    value={form.prix_promo}
                    onChange={(e) =>
                      setForm((p) => ({ ...p, prix_promo: e.target.value }))
                    }
                  />
                </label>
              </div>

              <div className="modal-foot">
                <button
                  className="btn-ghost"
                  type="button"
                  onClick={() => setOpen(false)}
                >
                  Annuler
                </button>
                <button className="btn-primary" type="submit">
                  Enregistrer
                </button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </section>
  );
}
