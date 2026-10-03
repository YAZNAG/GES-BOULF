import { useEffect, useMemo, useState } from "react";
import { ArrowDownLeft, ArrowUpRight, Calendar, Search, X, FileDown, Info, ChevronRight } from "lucide-react";
import { CSVLink } from "react-csv";
import { useOutletContext } from "react-router-dom";
import { apiFetch } from "../../lib/api";
import "../../styles/mouvements-stock.css";

export default function MouvementsStock() {
  const outlet = useOutletContext() || {};
  const search = (outlet.search || "").toString();
  const setSearch =
    typeof outlet.setSearch === "function" ? outlet.setSearch : () => {};

  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [filterType, setFilterType] = useState('all');
  const [filterPeriod, setFilterPeriod] = useState('all');
  const [selected, setSelected] = useState(null);
  const [selectedInvoice, setSelectedInvoice] = useState(null);

  async function loadAll() {
    setLoading(true);
    setError("");
    try {
      const res = await apiFetch("/api/mouvements_stock?per_page=1000");
      const data = Array.isArray(res?.data) ? res.data : res?.data?.data || [];
      setItems(data);
    } catch (e) {
      setError(e?.message || "Erreur lors du chargement des mouvements");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadAll();
  }, []);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    const now = new Date();
    
    return items.filter((m) => {
      if (!m.created_at) return false;
      const mDate = new Date(m.created_at);
      
      // Search
      const articleNom = (m?.article?.nom || "").toLowerCase();
      const code = (m?.article?.code_article || "").toLowerCase();
      const matchSearch = !q || articleNom.includes(q) || code.includes(q);
      
      // Type Filter
      let matchType = true;
      if (filterType === 'entree') matchType = m.type_mouvement === 'entree';
      else if (filterType === 'sortie') matchType = m.type_mouvement === 'sortie';
      else if (filterType === 'retour') matchType = m.motif?.toLowerCase() === 'retour';
      else if (filterType === 'ajustement') matchType = m.motif?.toLowerCase() === 'ajustement';
      
      // Period Filter
      let matchPeriod = true;
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const itemDate = new Date(m.created_at);
      itemDate.setHours(0, 0, 0, 0);

      if (filterPeriod === 'today') {
        matchPeriod = itemDate.getTime() === today.getTime();
      } else if (filterPeriod === 'week') {
        const weekAgo = new Date();
        weekAgo.setDate(today.getDate() - 7);
        weekAgo.setHours(0, 0, 0, 0);
        matchPeriod = itemDate >= weekAgo;
      } else if (filterPeriod === 'month') {
        const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
        matchPeriod = itemDate >= monthStart;
      }
      
      return matchSearch && matchType && matchPeriod;
    });
  }, [items, search, filterType, filterPeriod]);

  const grouped = useMemo(() => {
    const groups = {};
    filtered.forEach(m => {
      const date = new Date(m.created_at).toDateString();
      if (!groups[date]) groups[date] = [];
      groups[date].push(m);
    });
    return Object.entries(groups).sort((a, b) => new Date(b[0]) - new Date(a[0]));
  }, [filtered]);

  const stats = useMemo(() => {
    let entree = 0;
    let sortie = 0;
    for (const m of filtered) {
      if (m?.type_mouvement === "entree") entree += Number(m.quantite || 0);
      if (m?.type_mouvement === "sortie") sortie += Number(m.quantite || 0);
    }
    return { count: filtered.length, entree, sortie };
  }, [filtered]);

  return (
    <div className="content movements-page">
      <div className="movements-shell">
        <div className="movements-header-v2">
          <div className="movements-title-section">
            <h1 className="movements-title-v2">Historique des Mouvements</h1>
            <p className="movements-subtitle-v2">Suivez l'activité de votre stock en temps réel</p>
          </div>
          
          <div className="movements-stats-grid">
            <div className="m-stat-card total">
              <div className="m-stat-icon"><Info size={20} /></div>
              <div className="m-stat-info">
                <span className="m-stat-label">Total</span>
                <span className="m-stat-value">{stats.count}</span>
              </div>
            </div>
            <div className="m-stat-card entries">
              <div className="m-stat-icon"><ArrowUpRight size={20} /></div>
              <div className="m-stat-info">
                <span className="m-stat-label">Entrées</span>
                <span className="m-stat-value">+{stats.entree.toFixed(0)}</span>
              </div>
            </div>
            <div className="m-stat-card exits">
              <div className="m-stat-icon"><ArrowDownLeft size={20} /></div>
              <div className="m-stat-info">
                <span className="m-stat-label">Sorties</span>
                <span className="m-stat-value">-{stats.sortie.toFixed(0)}</span>
              </div>
            </div>
          </div>
        </div>

        <div className="movements-filter-bar">
          <div className="filter-group search">
            <Search size={18} className="search-icon" />
            <input
              placeholder="Rechercher un article ou code..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          
          <div className="filter-group">
            <select value={filterType} onChange={(e) => setFilterType(e.target.value)}>
              <option value="all">Tous les types</option>
              <option value="entree">Entrées (+)</option>
              <option value="sortie">Sorties (-)</option>
              <option value="retour">Retours</option>
              <option value="ajustement">Ajustements</option>
            </select>
          </div>

          <div className="filter-group">
            <select value={filterPeriod} onChange={(e) => setFilterPeriod(e.target.value)}>
              <option value="all">Toute la période</option>
              <option value="today">Aujourd'hui</option>
              <option value="week">7 derniers jours</option>
              <option value="month">Ce mois-ci</option>
            </select>
          </div>

          <button className="refresh-btn" onClick={loadAll} disabled={loading}>
            <Calendar size={18} />
          </button>

          <CSVLink 
            data={filtered.map(m => ({
              Date: new Date(m.created_at).toLocaleString(),
              Article: m.article?.nom,
              Code: m.article?.code_article,
              Type: m.type_mouvement,
              Motif: m.motif,
              Quantité: m.quantite,
              Utilisateur: m.utilisateur?.nom,
              Note: m.note
            }))}
            filename={`mouvements_${new Date().toISOString().split('T')[0]}.csv`}
            className="export-btn"
          >
            <FileDown size={18} />
          </CSVLink>
        </div>

        {error ? <div className="movements-error">{error}</div> : null}

        <div className="movements-body-v2">
          {loading ? (
            <div className="m-loading-v2">
              <div className="spinner-v2" />
              <span>Chargement de l'historique...</span>
            </div>
          ) : filtered.length === 0 ? (
            <div className="m-empty-v2">
              <Info size={48} />
              <p>Aucun mouvement trouvé pour cette période.</p>
            </div>
          ) : (
            <div className="m-timeline">
              {grouped.map(([date, group]) => {
                const invoices = {};
                group.forEach(m => {
                  const ref = (m.reference_type && (m.reference_type.startsWith('ENT-') || m.reference_type.startsWith('SOR-'))) ? m.reference_type : 'Individual';
                  if (!invoices[ref]) invoices[ref] = [];
                  invoices[ref].push(m);
                });

                return (
                  <div key={date} className="timeline-day">
                    <div className="day-header">
                      <span className="day-name">
                        {new Date(date).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })}
                      </span>
                      <span className="day-count">{group.length} mouvements</span>
                    </div>
                    
                    <div className="day-items">
                      {Object.entries(invoices).map(([ref, invGroup]) => (
                        <div key={ref} className={`invoice-group ${ref !== 'Individual' ? 'has-invoice' : ''}`}>
                          {ref !== 'Individual' && (
                            <div className="invoice-header">
                              <span className="invoice-num"><FileDown size={14} /> {ref}</span>
                              <span className="invoice-total">{invGroup.length} articles</span>
                              <button className="print-inv-btn" onClick={() => setSelectedInvoice({ ref, items: invGroup })}>
                                Voir Facture
                              </button>
                            </div>
                          )}
                          
                          <div className="invoice-items-list">
                            {invGroup.map((m) => (
                              <div 
                                key={m.id} 
                                className={`m-card ${m.type_mouvement}`}
                                onClick={() => setSelected(m)}
                              >
                                <div className="m-card-icon">
                                  {m.type_mouvement === 'entree' ? <ArrowUpRight size={20} /> : <ArrowDownLeft size={20} />}
                                </div>
                                
                                <div className="m-card-content">
                                  <div className="m-card-header">
                                    <span className="m-article-name">{m.article?.nom}</span>
                                    <span className={`m-qty-badge ${m.type_mouvement}`}>
                                      {m.type_mouvement === 'entree' ? '+' : '-'}{Number(m.quantite).toFixed(0)}
                                    </span>
                                  </div>
                                  
                                  <div className="m-card-meta">
                                    <span className="m-time">
                                      {new Date(m.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                                    </span>
                                    <span className="m-divider">•</span>
                                    <span className="m-motif">{m.motif}</span>
                                    {m.note && (
                                      <>
                                        <span className="m-divider">•</span>
                                        <span className="m-note">{m.note}</span>
                                      </>
                                    )}
                                  </div>
                                </div>
                                
                                <div className="m-card-arrow">
                                  <ChevronRight size={18} />
                                </div>
                              </div>
                            ))}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
        <div className="movements-footer">
          <div className="stat-card">
            <div className="stat-card-label">Total Mouvements</div>
            <div className="stat-card-value">{stats.count}</div>
          </div>
          <div className="stat-card">
            <div className="stat-card-label" style={{ color: '#22c55e' }}>Total Entrées (+)</div>
            <div className="stat-card-value" style={{ color: '#22c55e' }}>{stats.entree.toFixed(3)}</div>
          </div>
          <div className="stat-card">
            <div className="stat-card-label" style={{ color: '#ef4444' }}>Total Sorties (-)</div>
            <div className="stat-card-value" style={{ color: '#ef4444' }}>{stats.sortie.toFixed(3)}</div>
          </div>
        </div>

        {selected && (
          <div className="modal-overlay" onClick={() => setSelected(null)}>
            <div className="modal" onClick={e => e.stopPropagation()} style={{ width: '450px' }}>
              <div className="modal-head">
                <div className="modal-title"><Info size={18} /> Détails du mouvement</div>
                <button className="modal-x" onClick={() => setSelected(null)}><X size={20} /></button>
              </div>
              <div className="modal-body">
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  <div className="detail-item">
                    <div className="detail-item-label">Article</div>
                    <div className="detail-item-value">{selected.article?.nom} ({selected.article?.code_article})</div>
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px' }}>
                    <div className="detail-item">
                      <div className="detail-item-label">Type</div>
                      <div className="detail-item-value" style={{ color: selected.type_mouvement === 'entree' ? '#22c55e' : '#ef4444' }}>
                        {selected.type_mouvement.toUpperCase()}
                      </div>
                    </div>
                    <div className="detail-item">
                      <div className="detail-item-label">Motif</div>
                      <div className="detail-item-value">{selected.motif}</div>
                    </div>
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px' }}>
                    <div className="detail-item">
                      <div className="detail-item-label">Quantité</div>
                      <div className="detail-item-value" style={{ fontSize: '18px' }}>{selected.quantite}</div>
                    </div>
                    <div className="detail-item">
                      <div className="detail-item-label">Utilisateur</div>
                      <div className="detail-item-value">{selected.utilisateur?.nom || 'Système'}</div>
                    </div>
                  </div>
                  {selected.fournisseur && (
                    <div className="detail-item">
                      <div className="detail-item-label">Fournisseur</div>
                      <div className="detail-item-value">{selected.fournisseur.nom}</div>
                    </div>
                  )}
                  <div className="detail-item">
                    <div className="detail-item-label">Date & Heure</div>
                    <div className="detail-item-value">{new Date(selected.created_at).toLocaleString()}</div>
                  </div>
                  <div className="detail-item">
                    <div className="detail-item-label">Note</div>
                    <div className="detail-note-box">
                      {selected.note || 'Aucune note'}
                    </div>
                  </div>
                </div>
              </div>
              <div className="modal-foot">
                <button className="btn-ghost" onClick={() => setSelected(null)}>Fermer</button>
              </div>
            </div>
          </div>
        )}
        {selectedInvoice && (
          <div id="printable-invoice" className="modal-overlay" onClick={() => setSelectedInvoice(null)}>
            <div className="modal invoice-modal" onClick={e => e.stopPropagation()}>
              <div className="modal-head no-print">
                <div className="modal-title">Facture d'Entrée Stock</div>
                <button className="modal-x" onClick={() => setSelectedInvoice(null)}><X size={20} /></button>
              </div>
              <div className="modal-body invoice-printable">
                <div className="invoice-info-header">
                  <div>
                    <div className="inv-label">Numéro Facture</div>
                    <div className="inv-value">{selectedInvoice.ref}</div>
                  </div>
                  <div>
                    <div className="inv-label">Date</div>
                    <div className="inv-value">{new Date(selectedInvoice.items[0].created_at).toLocaleString()}</div>
                  </div>
                </div>
                
                <div className="inv-supplier-info">
                  <div className="inv-label">Fournisseur</div>
                  <div className="inv-value">{selectedInvoice.items[0].fournisseur?.nom || 'Non spécifié'}</div>
                </div>

                <table className="inv-table">
                  <thead>
                    <tr>
                      <th>Article</th>
                      <th>Code</th>
                      <th style={{ textAlign: 'right' }}>Quantité</th>
                    </tr>
                  </thead>
                  <tbody>
                    {selectedInvoice.items.map(it => (
                      <tr key={it.id}>
                        <td>{it.article?.nom}</td>
                        <td>{it.article?.code_article}</td>
                        <td style={{ textAlign: 'right', fontWeight: 800 }}>{it.quantite} {it.article?.unite}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className="modal-foot">
                <button className="btn-ghost" onClick={() => setSelectedInvoice(null)}>Fermer</button>
                <button className="btn-primary" onClick={() => window.print()}>Imprimer</button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
