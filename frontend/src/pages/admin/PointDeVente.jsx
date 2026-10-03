import React, { useState, useEffect, useRef } from 'react';
import { Search, Trash2, Plus, Minus, User, Monitor, X, ChevronLeft, ChevronRight } from 'lucide-react';
import { usePOS } from '../../features/pos/usePOS';
import { toast } from '../../lib/toast';
import '../../styles/pos.css';

export default function PointDeVente() {
  const {
    articles,
    categories,
    clients,
    loading,
    search,
    setSearch,
    selectedCategory,
    setSelectedCategory,
    cart,
    addToCart,
    removeFromCart,
    updateQty,
    clearCart,
    totals,
    selectedClient,
    setSelectedClient,
    isPaymentModalOpen,
    setIsPaymentModalOpen,
    saleResult,
    setSaleResult,
    confirmSale,
    submitting,
    paymentMethods
  } = usePOS();

  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [scannerMode, setScannerMode] = useState(true); // Default to scanner mode active
  const itemsPerPage = 12;

  useEffect(() => {
    setCurrentPage(1);
  }, [search, selectedCategory]);

  const totalPages = Math.ceil(articles.length / itemsPerPage) || 1;
  const paginatedArticles = articles.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  useEffect(() => {
    const handleResize = () => {
      if (window.innerWidth > 1024) {
        setIsSidebarOpen(false);
      }
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  const searchInputRef = useRef(null);

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'F2') {
        e.preventDefault();
        setScannerMode(false);
        searchInputRef.current?.focus();
      }
      if (e.key === 'F4') {
        e.preventDefault();
        setScannerMode(true);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  // Auto-focus search input when scanner mode is active
  useEffect(() => {
    if (scannerMode && !isPaymentModalOpen && !saleResult) {
      const timer = setTimeout(() => {
        searchInputRef.current?.focus();
      }, 100);
      return () => clearTimeout(timer);
    }
  }, [scannerMode, isPaymentModalOpen, saleResult, cart.length]); // Refocus after adding to cart too

  useEffect(() => {
    let barcodeBuffer = '';
    let lastKeyTime = Date.now();

    const handleGlobalKeyDown = (e) => {
      // If we are typing in an input but NOT in scanner mode, ignore global barcode logic
      if (
        (document.activeElement?.tagName === 'INPUT' || document.activeElement?.tagName === 'TEXTAREA') &&
        !scannerMode
      ) {
        return;
      }

      // Scanner mode: redirect all alphanumeric input to barcode buffer if not in an input
      // OR even if in input if scannerMode is strictly forced (but let's be careful)
      
      const currentTime = Date.now();
      if (currentTime - lastKeyTime > 100) { // Increased to 100ms for more reliability
        barcodeBuffer = '';
      }
      lastKeyTime = currentTime;

      if (e.key.length === 1 && /^[a-zA-Z0-9]$/.test(e.key)) {
        barcodeBuffer += e.key;
        // Optional: if in scanner mode and NOT in search input, prevent default to avoid accidental scrolling/triggers
        // if (scannerMode && document.activeElement?.tagName !== 'INPUT') e.preventDefault();
      } else if (e.key === 'Enter') {
        if (barcodeBuffer.length >= 3) {
          const code = barcodeBuffer.toLowerCase().trim();
          const exactMatch = articles.find(a => 
            a.code_article && a.code_article.toLowerCase() === code
          );
          if (exactMatch) {
            addToCart(exactMatch);
            setIsSidebarOpen(true);
            // Visual feedback
            toast({ type: 'success', message: `Ajouté: ${exactMatch.nom}` });
          } else {
            // Check if search input has a value that matches
            const searchCode = search.toLowerCase().trim();
            const searchMatch = articles.find(a => 
              a.code_article && a.code_article.toLowerCase() === searchCode
            );
            if (searchMatch) {
              addToCart(searchMatch);
              setSearch('');
              setIsSidebarOpen(true);
            }
          }
          barcodeBuffer = '';
          e.preventDefault();
        }
      }
    };

    window.addEventListener('keydown', handleGlobalKeyDown);
    return () => window.removeEventListener('keydown', handleGlobalKeyDown);
  }, [articles, addToCart, isPaymentModalOpen, saleResult, scannerMode, search, setSearch]);

  if (loading && articles.length === 0) {
    return <div className="page">Chargement du POS...</div>;
  }

  return (
    <div className={`pos-container ${isSidebarOpen ? 'sidebar-open' : ''} ${scannerMode ? 'scanner-active' : ''}`}>
      <div className="pos-main">
        <div className="pos-header">
            <div className="pos-header-content">
              <div className="pos-header-left">
                <button 
                  className={`scanner-mode-btn ${scannerMode ? 'active' : ''}`}
                  onClick={() => setScannerMode(!scannerMode)}
                  title="Basculer Mode Scanner (F4)"
                >
                  <Monitor size={20} />
                  <span>{scannerMode ? 'Mode Scanner' : 'Mode Recherche'}</span>
                </button>
              </div>

              <div className="pos-header-center">
                <div className="pos-search-wrapper">
                  <Search className="pos-search-icon" size={20} />
                  <input
                    ref={searchInputRef}
                    className="pos-search-input"
                    placeholder={scannerMode ? "Prêt à scanner..." : "Rechercher un produit... [F2]"}
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' && search) {
                        const exactMatch = articles.find(a => 
                          a.code_article && a.code_article.toLowerCase() === search.toLowerCase().trim()
                        );
                        if (exactMatch) {
                          addToCart(exactMatch);
                          setSearch(''); 
                          setIsSidebarOpen(true);
                          e.preventDefault();
                          // Visual feedback
                          toast({ type: 'success', message: `Ajouté: ${exactMatch.nom}` });
                        } else if (articles.length === 1) {
                          // Un seul résultat (nom FR/AR, marque) : Entrée l'ajoute directement.
                          addToCart(articles[0]);
                          setSearch('');
                          setIsSidebarOpen(true);
                          e.preventDefault();
                        } else if (/^\d{6,14}$/.test(search.trim())) {
                          toast({ type: 'error', message: `Code ${search.trim()} introuvable ou article non tarifé.` });
                          setSearch('');
                          e.preventDefault();
                        }
                      }
                    }}
                  />
                </div>
              </div>

              <div className="pos-header-right">
                <button 
                  className="mobile-cart-toggle" 
                  onClick={() => setIsSidebarOpen(true)}
                >
                  <Monitor size={24} />
                  <span className="cart-badge">{cart.length}</span>
                </button>
                <div className="pos-category-select-wrapper">
                  <select
                    className="pos-category-select"
                    value={selectedCategory}
                    onChange={(e) => setSelectedCategory(e.target.value)}
                  >
                    <option value="all">Toutes catégories</option>
                    {categories.map(cat => (
                      <option key={cat.id} value={cat.id}>
                        {cat.nom}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
            </div>
        </div>

        <div className="pos-grid-container">
            <div className="pos-grid">
            {paginatedArticles.map((article) => {
                const stock = Number(article.stock || 0)
                const stockTone = stock <= 0 ? 'out' : stock <= 5 ? 'low' : 'ok'
                const price = selectedClient?.type_client === 'gros' ? article.prix_gros : article.prix
                return (
                <div
                key={article.id}
                className="pos-product-card"
                onClick={() => addToCart(article)}
                >
                <div className="pos-product-media">
                    {article.img && article.img !== '/imagelogin.png' ? (
                    <img className="pos-product-img" src={article.img} alt={article.nom} loading="lazy" />
                    ) : (
                    <div className="pos-product-img-fallback" aria-hidden="true">
                        <Monitor size={40} />
                    </div>
                    )}
                </div>
                <div className="pos-product-info">
                    <div className="pos-product-name">{article.nom}</div>
                    <div className={`pos-stock-badge pos-stock-${stockTone}`}>Stock : {article.stock}</div>
                    <div className="pos-price-text">{Number(price).toFixed(2)} MAD</div>
                </div>
                </div>
                )
            })}
            {articles.length === 0 && (
                <div className="pos-cart-empty" style={{ gridColumn: '1 / -1' }}>
                <Search size={48} />
                <p>Aucun produit trouvé</p>
                </div>
            )}
            </div>

            {articles.length > 0 && (
                <div className="pos-pagination">
                <button 
                    className="pos-page-btn" 
                    onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                    disabled={currentPage === 1}
                >
                    <ChevronLeft size={24} />
                </button>
                <button 
                    className="pos-page-btn" 
                    onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                    disabled={currentPage === totalPages}
                >
                    <ChevronRight size={24} />
                </button>
                </div>
            )}
        </div>
      </div>

      {/* SIDEBAR: CART */}
      {isSidebarOpen && <div className="pos-sidebar-overlay" onClick={() => setIsSidebarOpen(false)}></div>}
      <div className={`pos-sidebar ${isSidebarOpen ? 'open' : 'closed'}`}>
        <div className="pos-sidebar-header">
          <div className="pos-sidebar-title">Panier ({cart.length})</div>
          <button className="pos-sidebar-close" onClick={() => setIsSidebarOpen(false)}>
            <X size={24} />
          </button>
        </div>
        <div className="pos-client-section">
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
            <User size={18} color="#64748b" />
            <span style={{ fontWeight: 700, fontSize: '14px', color: '#64748b' }}>Client</span>
          </div>
          <select
            className="pos-client-selector"
            value={selectedClient?.id || ''}
            onChange={(e) => {
              const client = clients.find(c => String(c.id) === e.target.value);
              setSelectedClient(client || null);
            }}
          >
            <option value="">Client de passage</option>
            {clients.map(client => (
              <option key={client.id} value={client.id}>
                {client.nom} {client.type_client === 'gros' ? '(Gros)' : ''}
              </option>
            ))}
          </select>
          {selectedClient && selectedClient.solde > 0 && (
            <div style={{ marginTop: '8px', color: '#ef4444', fontSize: '12px', fontWeight: 700 }}>
              ⚠️ Solde impayé: {selectedClient.solde} MAD
            </div>
          )}
        </div>

        <div className="pos-cart">
          {cart.length === 0 ? (
            <div className="pos-cart-empty">
              <Trash2 size={48} />
              <p>Le panier est vide</p>
            </div>
          ) : (
            cart.map(item => (
              <div key={item.id} className="pos-cart-item">
                <div className="pos-item-header">
                  <div className="pos-item-name">{item.nom}</div>
                  <Trash2
                    className="pos-item-remove"
                    size={16}
                    onClick={() => removeFromCart(item.id)}
                  />
                </div>
                <div className="pos-item-controls">
                  <div className="pos-qty-btns">
                    <button className="pos-qty-btn" onClick={() => updateQty(item.id, -1, true)}><Minus size={14} /></button>
                    <input 
                      className="pos-qty-input" 
                      type="number" 
                      step="0.001" 
                      value={item.qty} 
                      onChange={(e) => updateQty(item.id, e.target.value)}
                      onFocus={(e) => e.target.select()}
                    />
                    <button className="pos-qty-btn" onClick={() => updateQty(item.id, 1, true)}><Plus size={14} /></button>
                    <span className="pos-cart-unite">{item.unite}</span>
                  </div>
                  <div className="pos-item-total">
                    <span className="pos-item-total-price">
                      {((selectedClient?.type_client === 'gros' ? item.prix_gros : item.prix) * item.qty).toFixed(2)} MAD
                    </span>
                    <span className="pos-item-breakdown">
                      {item.qty} × {(selectedClient?.type_client === 'gros' ? item.prix_gros : item.prix).toFixed(2)}
                    </span>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>

        <div className="pos-totals">
          <div className="pos-total-final">
            <span>TOTAL</span>
            <span>{totals.total.toFixed(2)} MAD</span>
          </div>
        </div>

        <div className="pos-actions">
          <button className="pos-btn-clear" onClick={clearCart}>Vider</button>
          <button
            className="pos-btn-confirm"
            disabled={cart.length === 0}
            onClick={() => setIsPaymentModalOpen(true)}
          >
            Confirmer
          </button>
        </div>
      </div>

      {/* PAYMENT MODAL */}
      {isPaymentModalOpen && (
        <PaymentModal
          total={totals.total}
          paymentMethods={paymentMethods}
          onClose={() => setIsPaymentModalOpen(false)}
          onConfirm={confirmSale}
          submitting={submitting}
        />
      )}
      {/* SUCCESS MODAL */}
      {saleResult && (
        <SuccessModal 
          result={saleResult} 
          onClose={() => setSaleResult(null)} 
        />
      )}
    </div>
  );
}

function SuccessModal({ result, onClose }) {
  return (
    <div id="printable-invoice" className="modal-overlay pos-receipt-overlay">
      <div className="modal pos-receipt-modal">
        <div className="modal-body pos-receipt-body">
          <div className="pos-receipt-invoice">
            <div style={{ textAlign: 'center', marginBottom: '15px' }}>
              <h2 style={{ fontSize: '18px', fontWeight: 900, margin: 0, color: '#0f172a' }}>EL HERRI</h2>
              <p style={{ fontSize: '12px', color: '#64748b', margin: '2px 0 10px' }}>Reçu de Vente</p>
              <hr style={{ border: 'none', borderTop: '1px solid #e2e8f0', margin: '10px 0' }} />
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
              <span style={{ color: '#64748b' }}>N° Facture:</span>
              <span style={{ fontWeight: 700 }}>{result.numero_facture}</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
              <span style={{ color: '#64748b' }}>Client:</span>
              <span style={{ fontWeight: 700 }}>{result.client?.nom || 'Client de passage'}</span>
            </div>
            <hr style={{ border: 'none', borderTop: '1px solid #e2e8f0', margin: '10px 0' }} />

            {/* Liste des produits achetés */}
            {result.items && result.items.length > 0 && (
              <div style={{ marginBottom: '15px' }}>
                <table style={{ width: '100%', fontSize: '12px', borderCollapse: 'collapse' }}>
                  <thead>
                    <tr style={{ borderBottom: '1px solid #e2e8f0', color: '#64748b' }}>
                      <th style={{ textAlign: 'left', paddingBottom: '5px' }}>Produit</th>
                      <th style={{ textAlign: 'center', paddingBottom: '5px' }}>Qté</th>
                      <th style={{ textAlign: 'right', paddingBottom: '5px' }}>Prix</th>
                    </tr>
                  </thead>
                  <tbody>
                    {result.items.map((item, index) => {
                      const price = result.client?.type_client === 'gros' ? item.prix_gros : item.prix;
                      return (
                        <tr key={index}>
                          <td style={{ padding: '5px 0', fontWeight: 600 }}>{item.nom}</td>
                          <td style={{ padding: '5px 0', textAlign: 'center' }}>{item.qty}</td>
                          <td style={{ padding: '5px 0', textAlign: 'right', fontWeight: 600 }}>
                            {(price * item.qty).toFixed(2)}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}

            <hr style={{ border: 'none', borderTop: '1px solid #e2e8f0', margin: '10px 0' }} />
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
              <span style={{ color: '#64748b' }}>Total:</span>
              <span style={{ fontWeight: 700 }}>{result.total.toFixed(2)} MAD</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
              <span style={{ color: '#64748b' }}>Payé:</span>
              <span style={{ fontWeight: 700 }}>{result.paid.toFixed(2)} MAD</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', color: '#16a34a' }}>
              <span style={{ fontWeight: 700 }}>{result.paid < result.total ? 'Reste (Crédit):' : 'Rendu:'}</span>
              <span style={{ fontWeight: 800 }}>{Math.abs(result.change).toFixed(2)} MAD</span>
            </div>
          </div>

          <div className="pos-receipt-actions">
            <button 
              className="btn-primary" 
              style={{ background: '#1e293b' }}
              onClick={() => window.print()}
            >
              Imprimer
            </button>
            <button 
              className="btn-ghost" 
              style={{ border: '1px solid #e2e8f0' }}
              onClick={onClose}
            >
              Nouvelle vente
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

function PaymentModal({ total, paymentMethods, onClose, onConfirm, submitting }) {
  const [method, setMethod] = useState(() => {
    if (paymentMethods && paymentMethods.length > 0) return paymentMethods[0].nom.toLowerCase();
    return 'espèces';
  });
  const [amountPaid, setAmountPaid] = useState(total);

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()} style={{ width: '500px' }}>
        <div className="modal-head">
          <div className="modal-title">Finaliser la vente</div>
          <button className="modal-close" onClick={onClose}><X size={20} /></button>
        </div>
        <div className="modal-body">
          <div className="pos-payment-grid">
            <div className="payment-input-group">
              <label className="form-label">Montant à payer</label>
              <div className="payment-input" style={{ background: '#f8fafc' }}>
                {total.toFixed(2)} MAD
              </div>
            </div>
            <div className="payment-input-group">
              <label className="form-label">Montant reçu</label>
              <input
                type="number"
                className="payment-input"
                value={amountPaid}
                onChange={e => setAmountPaid(Number(e.target.value))}
                autoFocus
              />
            </div>
          </div>

          <div style={{ marginTop: '20px' }}>
            <label className="form-label">Mode de paiement</label>
            <div className="payment-methods">
              {paymentMethods.map(m => (
                <button
                  key={m.id}
                  className={`method-btn ${method === m.nom.toLowerCase() ? 'active' : ''}`}
                  onClick={() => setMethod(m.nom.toLowerCase())}
                >
                  <span style={{ textTransform: 'capitalize' }}>{m.nom}</span>
                </button>
              ))}
              <button
                className={`method-btn ${method === 'credit' ? 'active' : ''}`}
                onClick={() => setMethod('credit')}
              >
                <span>Crédit</span>
              </button>
            </div>
          </div>

          <div className="change-display">
            <span className="change-label">{amountPaid < total ? 'Reste à payer (Dette)' : 'Rendu'}</span>
            <span className={`change-amount ${amountPaid < total ? 'text-danger' : ''}`}>
              {Math.abs(amountPaid - total).toFixed(2)} MAD
            </span>
          </div>

          <div className="modal-foot" style={{ marginTop: '20px' }}>
            <button className="btn-ghost" onClick={onClose} disabled={submitting}>Annuler</button>
            <button
              className="btn-primary"
              style={{ background: '#ef4444' }}
              onClick={() => onConfirm({ method, amountPaid })}
              disabled={submitting}
            >
              {submitting ? 'Traitement...' : 'Valider la vente'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
