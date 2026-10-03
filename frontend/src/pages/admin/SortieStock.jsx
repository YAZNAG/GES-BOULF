import { useEffect, useMemo, useRef, useState } from "react";
import { Camera, Check, Pencil, Plus, X } from "lucide-react";
import { useOutletContext } from "react-router-dom";
import { apiFetch } from "../../lib/api";
import Alert from "../../components/Alert";
import ProductModal from "../../components/products/ProductModal";
import "../../styles/mouvements-stock.css";
import "../../styles/produits.css";

export default function SortieStock() {
  const outlet = useOutletContext() || {};
  const search = (outlet.search || outlet.searchQuery || "").toString();

  const [articles, setArticles] = useState([]);
  const [sousCategories, setSousCategories] = useState([]);
  const [stocks, setStocks] = useState([]);
  const [mouvements, setMouvements] = useState([]);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [open, setOpen] = useState(false);

  const [toast, setToast] = useState(null);
  const [missingCode, setMissingCode] = useState("");
  const [askAddOpen, setAskAddOpen] = useState(false);
  const [addProductOpen, setAddProductOpen] = useState(false);

  const [barcode, setBarcode] = useState("");

  const [articleQuery, setArticleQuery] = useState("");

  const [items, setItems] = useState([]);
  const [batchMotif, setBatchMotif] = useState("vente");
  const [batchNote, setBatchNote] = useState("");


  async function loadAll() {
    setLoading(true);
    setError("");
    try {
      const [articlesRes, stockRes, mouvRes, scRes] = await Promise.all([
        apiFetch("/api/articles?per_page=1000"),
        apiFetch("/api/stock?per_page=1000"),
        apiFetch("/api/mouvements_stock?per_page=1000"),
        apiFetch("/api/sous_categories?per_page=1000"),
      ]);

      const a = Array.isArray(articlesRes?.data)
        ? articlesRes.data
        : articlesRes?.data?.data || [];
      const s = Array.isArray(stockRes?.data)
        ? stockRes.data
        : stockRes?.data?.data || [];
      const m = Array.isArray(mouvRes?.data)
        ? mouvRes.data
        : mouvRes?.data?.data || [];
      const sc = Array.isArray(scRes?.data) ? scRes.data : scRes?.data?.data || [];

      setArticles(a);
      setStocks(s);
      setMouvements(m);
      setSousCategories(sc);
    } catch (e) {
      setError(e?.message || "Erreur");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadAll();
  }, []);

  const articleById = useMemo(
    () => new Map(articles.map((a) => [String(a.id), a])),
    [articles],
  );
  const stockByArticleId = useMemo(
    () => new Map(stocks.map((s) => [String(s.article_id), s])),
    [stocks],
  );
  const articleByCode = useMemo(() => {
    const map = new Map();
    for (const a of articles) {
      const code = (a?.code_article || "").toString().trim();
      if (code) map.set(code, a);
    }
    return map;
  }, [articles]);

  const filteredMouvements = useMemo(() => {
    const q = search.trim().toLowerCase();
    const list = mouvements.filter(
      (m) => (m?.type_mouvement || "").toString() === "sortie",
    );
    if (!q) return list;
    return list.filter((m) => {
      const numero = (m?.id || "").toString().toLowerCase();
      const articleNom = (
        m?.article?.nom ||
        articleById.get(String(m?.article_id || ""))?.nom ||
        ""
      )
        .toString()
        .toLowerCase();
      const motif = (m?.motif || "").toString().toLowerCase();
      return numero.includes(q) || articleNom.includes(q) || motif.includes(q);
    });
  }, [mouvements, search, articleById]);

  function formatDate(dateString) {
    if (!dateString) return "";
    const d = new Date(dateString);
    const pad = (n) => n.toString().padStart(2, "0");
    return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  function addItem(a) {
    if (!a) return;
    setItems((prev) => {
      const existingIdx = prev.findIndex(
        (it) => String(it.article_id) === String(a.id),
      );
      if (existingIdx >= 0) {
        const existing = prev[existingIdx];
        const filtered = prev.filter((_, i) => i !== existingIdx);
        return [
          {
            ...existing,
            quantite: Number(existing.quantite || 0) + 1,
          },
          ...filtered,
        ];
      }
      return [
        {
          article_id: a.id,
          code_article: a.code_article,
          nom: a.nom,
          quantite: 1,
        },
        ...prev,
      ];
    });
    showToast({
      type: "success",
      title: "Article ajouté",
      message: `${a.nom}`,
    });
  }

  function showToast(next) {
    setToast(next);
    window.clearTimeout(showToast._t);
    showToast._t = window.setTimeout(() => setToast(null), 2600);
  }


  function onBarcode(value) {
    const code = (value || "").toString().trim();
    if (!code) return;

    const a = articleByCode.get(code);
    if (!a) {
      setMissingCode(code);
      setAskAddOpen(true);
      showToast({
        type: "error",
        title: "Code-barres introuvable",
        message: `Aucun article avec le code ${code}.`,
      });
      return;
    }

    addItem(a);
    setBarcode("");
  }

  async function createProduct(values) {
    setSubmitting(true);
    setError("");
    try {
      const form = new FormData();
      form.append("sous_categorie_id", String(values.sous_categorie_id));
      form.append("code_article", String(values.code_article || ""));
      form.append("nom", String(values.nom || ""));
      form.append("unite", String(values.unite || "pièce"));
      form.append("actif", "1");
      if (values?.file) form.append("image", values.file);

      const article = await apiFetch("/api/articles", {
        method: "POST",
        body: form,
      });

      await apiFetch("/api/prix_articles", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          article_id: article.id,
          prix_achat: 0,
          prix_vente: Number(values.prix || 0),
          prix_gros: null,
          prix_promo: null,
        }),
      });

      await apiFetch("/api/stock", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          article_id: article.id,
          quantite: 0,
          seuil_min: Number(values.seuil_min || 0),
        }),
      });

      setAddProductOpen(false);
      setAskAddOpen(false);
      setMissingCode("");
      showToast({
        type: "success",
        title: "Produit créé",
        message: `${article.nom}`,
      });
      await loadAll();
      addItem(article);
    } catch (e) {
      setError(e?.message || "Erreur");
      showToast({
        type: "error",
        title: "Création impossible",
        message: e?.message || "Erreur",
      });
    } finally {
      setSubmitting(false);
    }
  }

  async function validateBatch() {
    setError("");
    setSuccess("");
    if (items.length === 0) {
      showToast({
        type: "error",
        title: "Aucun article",
        message: "Scanne au moins un article.",
      });
      return;
    }

    setSubmitting(true);
    try {
      const motifMap = {
        vente: "vente",
        perte: "perte",
        don: "don",
        ajustement_sortie: "ajustement",
      };
      const motif = motifMap[batchMotif] || "vente";
      
      // Generate a unique batch number for this "Invoice" (Sortie)
      const nowStr = new Date().toISOString().replace(/[-:T]/g, "").slice(0, 12);
      const batchNumber = `SOR-${nowStr}-${Math.floor(1000 + Math.random() * 9000)}`;

      for (const it of items) {
        const article_id = Number(it.article_id);
        const quantite = Number(it.quantite);
        if (
          !Number.isFinite(article_id) ||
          !Number.isFinite(quantite) ||
          quantite <= 0
        )
          continue;

        let stock = stockByArticleId.get(String(article_id));
        if (!stock) {
          stock = await apiFetch("/api/stock", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ article_id, quantite: 0, seuil_min: 0 }),
          });
        }

        const currentQty = Number(stock?.quantite ?? 0);
        if (currentQty < quantite) {
          const a = articleById.get(String(article_id));
          throw new Error(`Stock insuffisant pour ${a?.nom || "cet article"}`);
        }

        if (motif === "vente") {
          await apiFetch(`/api/stock/${stock.id}`, {
            method: "PUT",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ quantite: currentQty - quantite }),
          });

          await apiFetch("/api/mouvements_stock", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              article_id,
              type_mouvement: "sortie",
              motif: "vente",
              quantite,
              note: batchNote || null,
              reference_type: batchNumber, // Link all items to this invoice
              reference_id: null,
            }),
          });
        } else {
          await apiFetch("/api/sorties", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              article_id,
              motif,
              quantite,
              note: batchNote || null,
            }),
          });
        }
      }

      setItems([]);
      setBarcode("");
      setBatchMotif("vente");
      setBatchNote("");
      setSuccess("Mouvement enregistré");
      showToast({
        type: "success",
        title: "Succès",
        message: "Mouvement enregistré.",
      });
      setOpen(false);
      await loadAll();
    } catch (e) {
      setError(e?.message || "Erreur");
      showToast({
        type: "error",
        title: "Erreur",
        message: e?.message || "Erreur",
      });
    } finally {
      setSubmitting(false);
    }
  }

  useEffect(() => {
    if (open) {
      const input = document.querySelector(".ms-form-input");
      input?.focus();
    }
  }, [open]);

  const scannedArticle =
    barcode.trim() && articleByCode.get(barcode.trim())
      ? articleByCode.get(barcode.trim())
      : null;
  const scannedStock = scannedArticle
    ? stockByArticleId.get(String(scannedArticle.id))
    : null;
  const scannedPrix = scannedArticle
    ? Number(scannedArticle?.prix?.prix_vente ?? 0)
    : 0;

  const manualCandidates = useMemo(() => {
    const q = articleQuery.trim().toLowerCase();
    if (!q) return articles;
    return articles.filter((a) => {
      const n = (a?.nom || "").toString().toLowerCase();
      const c = (a?.code_article || "").toString().toLowerCase();
      return n.includes(q) || c.includes(q);
    });
  }, [articles, articleQuery]);

  return (
    <section className="content">
      <div className="page-head">
        <div>
          <div className="page-title">Sortie de Stock</div>
          <div className="page-subtitle">Enregistrer une sortie de stock</div>
        </div>
        <button
          className="primary primary-pill"
          type="button"
          onClick={() => setOpen(true)}
        >
          <Plus size={16} />
          Nouveau Mouvement
        </button>
      </div>

      <Alert type="error" message={error} />
      <Alert type="success" message={success} />

      {open ? (
        <div className="modal-overlay" onClick={() => setOpen(false)}>
          <div className="modals" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <div className="modal-title">Nouveau Mouvement (Sortie)</div>
              <button
                className="modal-x"
                type="button"
                onClick={() => setOpen(false)}
                aria-label="Fermer"
              >
                <X size={18} />
              </button>
            </div>
            <div className="modal-body">
              <div className="ms-unified-container">
                <div className="ms-input-grid">
                  <div className="ms-input-card">
                    <div className="form-label">Scanner Article</div>
                    <div className="ms-barcode-row">
                      <input
                        className="ms-form-input"
                        autoFocus
                        value={barcode}
                        onChange={(e) => setBarcode(e.target.value)}
                        onKeyDown={(e) => {
                          if (e.key === "Enter") onBarcode(barcode);
                        }}
                        placeholder="Utilisez votre lecteur..."
                      />
                      <button
                        className="ms-btn-primary"
                        type="button"
                        onClick={() => onBarcode(barcode)}
                        disabled={submitting || loading || !barcode.trim()}
                      >
                        <Check size={18} />
                      </button>
                    </div>
                  </div>

                  <div className="ms-input-card">
                    <div className="form-label">Recherche Manuelle</div>
                    <div className="ms-search-row">
                      <input
                        className="ms-form-input"
                        value={articleQuery}
                        onChange={(e) => setArticleQuery(e.target.value)}
                        placeholder="Nom ou code..."
                      />
                    </div>
                    {articleQuery.trim() && (
                      <div className="ms-manual-list">
                        {manualCandidates.slice(0, 5).map((a) => (
                          <div 
                            key={a.id} 
                            className="ms-manual-item"
                            onClick={() => {
                              addItem(a);
                              setArticleQuery("");
                            }}
                          >
                            <div className="ms-manual-item-name">{a.nom}</div>
                            <div className="ms-manual-item-code">{a.code_article}</div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                </div>

                {scannedArticle && (
                  <div className="ms-article-preview-bar">
                    <div className="ms-preview-content">
                      <span className="ms-preview-name">{scannedArticle.nom}</span>
                      <span className="ms-preview-info">
                        Stock: {Number(scannedStock?.quantite ?? 0)} | Prix: {scannedPrix} MAD
                      </span>
                    </div>
                  </div>
                )}

                <div className="ms-batch-area">
                  <div className="ms-batch-header">
                    <div className="ms-batch-title">Articles sélectionnés ({items.length})</div>
                    <button 
                      className="ms-btn-danger ms-btn-sm"
                      onClick={() => setItems([])}
                      disabled={items.length === 0}
                    >
                      Tout vider
                    </button>
                  </div>

                  <div className="ms-batch-controls">
                    <div className="form-grid">
                      <label className="form-label">
                        Motif
                        <select className="form-select" value={batchMotif} onChange={e => setBatchMotif(e.target.value)}>
                          <option value="vente">Vente</option>
                          <option value="perte">Perte</option>
                          <option value="don">Don</option>
                          <option value="ajustement_sortie">Ajustement sortie</option>
                        </select>
                      </label>
                    </div>
                    <label className="form-label" style={{ marginTop: '12px' }}>
                      Note / Référence
                      <textarea 
                        className="form-input" 
                        rows="2" 
                        value={batchNote} 
                        onChange={e => setBatchNote(e.target.value)} 
                        placeholder="Note pour ce lot..."
                      />
                    </label>
                  </div>

                  <div className="ms-items-table-wrap">
                    <table className="ms-items-table">
                      <thead>
                        <tr>
                          <th>Article</th>
                          <th>Stock</th>
                          <th>Quantité</th>
                          <th style={{ width: '40px' }}></th>
                        </tr>
                      </thead>
                      <tbody>
                        {items.map((it) => {
                          const a = articleById.get(String(it.article_id));
                          const st = stockByArticleId.get(String(it.article_id));
                          return (
                            <tr key={it.article_id}>
                              <td>
                                <div className="ms-table-article">
                                  <span className="ms-table-name">{a?.nom || it.nom}</span>
                                  <span className="ms-table-code">{a?.code_article || it.code_article}</span>
                                </div>
                              </td>
                              <td>{Number(st?.quantite ?? 0)}</td>
                              <td className="ms-qty">
                                <input
                                  className="ms-form-input ms-qty-input"
                                  type="number"
                                  step="0.001"
                                  value={it.quantite}
                                  onChange={(e) => {
                                    const v = e.target.value;
                                    setItems(prev => prev.map(x => x.article_id === it.article_id ? { ...x, quantite: v } : x));
                                  }}
                                />
                              </td>
                              <td>
                                <button
                                  className="ms-btn-icon-danger"
                                  onClick={() => setItems(prev => prev.filter(x => x.article_id !== it.article_id))}
                                >
                                  <X size={14} />
                                </button>
                              </td>
                            </tr>
                          );
                        })}
                        {items.length === 0 && (
                          <tr>
                            <td colSpan="4" className="ms-empty-cell">Aucun article sélectionné</td>
                          </tr>
                        )}
                      </tbody>
                    </table>
                  </div>
                </div>

                <div className="ms-modal-foot">
                  <button className="ms-btn-ghost" onClick={() => setOpen(false)} disabled={submitting}>Annuler</button>
                  <button
                    className="ms-btn-primary"
                    onClick={validateBatch}
                    disabled={submitting || items.length === 0}
                  >
                    {submitting ? "Validation…" : "Valider la sortie"}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      ) : null}

      <div className="orders-card">
        <div className="orders-card-head">
          <div className="orders-card-title">Historique des sorties</div>
        </div>

        {loading ? (
          <div className="orders-empty">Loading…</div>
        ) : (
          <div className="orders-table-wrap">
            <table className="orders-table">
              <thead>
                <tr>
                  <th>id</th>
                  <th>Type</th>
                  <th>Article</th>
                  <th>Motif</th>
                  <th>Quantité</th>
                  <th>Date</th>
                </tr>
              </thead>
              <tbody>
                {filteredMouvements.map((m) => (
                  <tr key={m.id}>
                    <td>
                      <span className="movement-badge movement-badge-sortie">
                        {m.id}
                      </span>
                    </td>
                    <td>
                      <span className="movement-badge movement-badge-sortie">
                        Sortie
                      </span>
                    </td>
                    <td>
                      {m?.article?.nom ||
                        articleById.get(String(m?.article_id || ""))?.nom ||
                        "—"}
                    </td>
                    <td>{m.motif}</td>
                    <td>{m.quantite}</td>
                    <td>{formatDate(m.created_at)}</td>
                  </tr>
                ))}
                {filteredMouvements.length === 0 ? (
                  <tr>
                    <td colSpan="5" className="orders-empty-cell">
                      Aucun mouvement
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {askAddOpen ? (
        <div className="modal-overlay" onClick={() => setAskAddOpen(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <div className="modal-title">Code-barres introuvable</div>
              <button className="modal-x" type="button" onClick={() => setAskAddOpen(false)} aria-label="Fermer">
                <X size={18} />
              </button>
            </div>
            <div className="modal-body">
              <div className="form-label">{`Le code ${missingCode} n'existe pas dans la base.`}</div>
              <div className="modal-foot">
                <button
                  className="btn-ghost"
                  type="button"
                  onClick={() => {
                    setAskAddOpen(false);
                    setMissingCode("");
                  }}
                  disabled={submitting}
                >
                  Non
                </button>
                <button
                  className="btn-primary"
                  type="button"
                  onClick={() => {
                    setAskAddOpen(false);
                    setAddProductOpen(true);
                  }}
                  disabled={submitting}
                >
                  Ajouter produit
                </button>
              </div>
            </div>
          </div>
        </div>
      ) : null}

      <ProductModal
        key={`${addProductOpen ? '1' : '0'}-${missingCode || 'none'}`}
        open={addProductOpen}
        mode="create"
        initialValues={missingCode ? { code_article: missingCode } : null}
        sousCategories={sousCategories}
        onClose={() => {
          setAddProductOpen(false);
          setMissingCode("");
        }}
        onSubmit={createProduct}
      />

      {toast ? (
        <div className="ms-toast-wrap">
          <div
            className={
              toast.type === "error"
                ? "ms-toast ms-toast-error"
                : "ms-toast ms-toast-success"
            }
          >
            <div className="ms-toast-icon">
              {toast.type === "error" ? <X size={20} /> : <Check size={20} />}
            </div>
            <div>
              <div className="ms-toast-title">{toast.title}</div>
              <div className="ms-toast-message">{toast.message}</div>
            </div>
          </div>
        </div>
      ) : null}
    </section>
  );
}
