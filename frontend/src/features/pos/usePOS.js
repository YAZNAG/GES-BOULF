import { useState, useCallback, useMemo, useEffect } from 'react';
import { apiFetch } from '../../lib/api';
import { toast } from '../../lib/toast';

function mapArticle(a) {
  return {
    id: a.id,
    code_article: a.code_article,
    nom: a.nom,
    prix: Number(a?.prix?.prix_vente ?? 0),
    prix_gros: Number(a?.prix?.prix_gros ?? a?.prix?.prix_vente ?? 0),
    stock: Number(a?.stock?.quantite ?? 0),
    img: a.image || '/imagelogin.png',
    categorie_id: a?.sous_categorie?.categorie_id || null,
    unite: a.unite || 'pièce',
  };
}

export function usePOS() {
  const [articles, setArticles] = useState([]);
  const [categories, setCategories] = useState([]);
  const [clients, setClients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [cart, setCart] = useState([]);
  const [selectedClient, setSelectedClient] = useState(null);
  const [isPaymentModalOpen, setIsPaymentModalOpen] = useState(false);
  const [saleResult, setSaleResult] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const [paymentMethods, setPaymentMethods] = useState([]);

  // Load initial data
  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [artData, catData, cliData, payData] = await Promise.all([
        apiFetch('/api/articles?per_page=1000'),
        apiFetch('/api/categories?per_page=1000'),
        apiFetch('/api/clients?per_page=1000'),
        apiFetch('/api/mode_paiements?per_page=1000')
      ]);
      
      const mappedArticles = (artData?.data || artData || []).map(mapArticle);
      setArticles(mappedArticles);
      setCategories(catData?.data || catData || []);
      setClients(cliData?.data || cliData || []);
      
      const allPay = payData?.data || payData || [];
      setPaymentMethods(allPay.filter(p => p.actif));
    } catch {
      toast({ type: 'error', message: 'Erreur lors du chargement des données' });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Filtered articles
  const filteredArticles = useMemo(() => {
    const q = search.toLowerCase().trim();
    const filtered = articles.filter(a => {
      const matchSearch = !q || a.nom.toLowerCase().includes(q) || a.code_article.toLowerCase().includes(q);
      const matchCat = selectedCategory === 'all' || String(a.categorie_id) === String(selectedCategory);
      return matchSearch && matchCat;
    });

    // Prioritize products without real barcodes (auto-generated ART- or empty)
    return [...filtered].sort((a, b) => {
      const aNoBarcode = !a.code_article || a.code_article.startsWith('ART-');
      const bNoBarcode = !b.code_article || b.code_article.startsWith('ART-');
      
      if (aNoBarcode && !bNoBarcode) return -1;
      if (!aNoBarcode && bNoBarcode) return 1;
      return 0;
    });
  }, [articles, search, selectedCategory]);

  // Cart actions
  const addToCart = useCallback((article) => {
    if (article.stock <= 0) {
      toast({ type: 'error', message: `Stock épuisé pour "${article.nom}"` });
      return;
    }
    setCart(prev => {
      const existing = prev.find(item => item.id === article.id);
      if (existing) {
        if (existing.qty + 1 > article.stock) {
          toast({ type: 'warning', message: `Stock maximum atteint (${article.stock})` });
          return prev;
        }
        // Move to top and increment
        const filtered = prev.filter(item => item.id !== article.id);
        return [{ ...existing, qty: Number(existing.qty) + 1 }, ...filtered];
      }
      // Add new item to the top
      return [{ ...article, qty: 1 }, ...prev];
    });
  }, []);

  const removeFromCart = useCallback((id) => {
    setCart(prev => prev.filter(item => item.id !== id));
  }, []);

  const updateQty = useCallback((id, val, isDelta = false) => {
    setCart(prev => prev.map(item => {
      if (item.id === id) {
        let newQty;
        if (isDelta) {
          newQty = Number(item.qty) + Number(val);
        } else {
          newQty = Number(val);
        }
        
        if (newQty < 0) newQty = 0;
        
        if (newQty > item.stock) {
          toast({ type: 'warning', message: `Stock maximum atteint (${item.stock})` });
          newQty = item.stock;
        }
        
        return { ...item, qty: newQty };
      }
      return item;
    }));
  }, []);

  const clearCart = useCallback(() => {
    setCart([]);
    setSelectedClient(null);
  }, []);

  // Totals
  const totals = useMemo(() => {
    const total = cart.reduce((sum, item) => {
      const price = selectedClient?.type_client === 'gros' ? item.prix_gros : item.prix;
      return sum + (price * item.qty);
    }, 0);
    return {
      subtotal: total,
      discount: 0,
      total
    };
  }, [cart, selectedClient]);

  // Submit sale
  const confirmSale = useCallback(async (paymentInfo) => {
    setSubmitting(true);
    try {
      // In a real app, we'd send one POST to /api/pos/sale
      // For now, let's assume we have a backend endpoint that handles it
      const payload = {
        client_id: selectedClient?.id,
        items: cart.map(item => ({
          article_id: item.id,
          quantite: item.qty,
          prix_unitaire: selectedClient?.type_client === 'gros' ? item.prix_gros : item.prix,
          remise: 0
        })),
        montant_total: totals.total,
        montant_paye: paymentInfo.amountPaid,
        mode_paiement: paymentInfo.method,
        ...paymentInfo
      };

      const response = await apiFetch('/api/pos/sale', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      setSaleResult({
        ...response,
        client: selectedClient,
        total: totals.total,
        paid: paymentInfo.amountPaid,
        change: Math.max(0, paymentInfo.amountPaid - totals.total),
        items: [...cart]
      });

      toast({ type: 'success', message: 'Vente effectuée avec succès' });
      clearCart();
      setIsPaymentModalOpen(false);
      loadData(); // Refresh stock
    } catch (err) {
      toast({ type: 'error', message: err.message || 'Erreur lors de la vente' });
    } finally {
      setSubmitting(false);
    }
  }, [cart, selectedClient, totals, clearCart, loadData]);

  return {
    articles: filteredArticles,
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
  };
}
