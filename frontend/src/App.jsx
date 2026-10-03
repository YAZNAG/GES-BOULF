import './styles/admin.css'
import './styles/auth.css'
import './styles/base.css'
import { Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './auth/AuthContext.jsx'
import { useAuth } from './auth/authContext'
import AdminLayout from './components/layout/AdminLayout'
import Login from './pages/Login'
import Account from './pages/admin/Account'
import Categories from './pages/admin/Categories'
import Clients from './pages/admin/Clients'
import Dashboard from './pages/admin/Dashboard'
import EntreeStock from './pages/admin/EntreeStock'
import Fournisseurs from './pages/admin/Fournisseurs'
import Placeholder from './pages/admin/Placeholder'
import Prix from './pages/admin/Prix'
import Produits from './pages/admin/Produits'
import Promotions from './pages/admin/Promotions'
import Roles from './pages/admin/Roles'
import SortieStock from './pages/admin/SortieStock'
import Stock from './pages/admin/Stock'
import SousCategories from './pages/admin/SousCategories'
import Articles from './pages/admin/Articles'
import Utilisateurs from './pages/admin/Utilisateurs'
import Ventes from './pages/admin/Ventes'
import PointDeVente from './pages/admin/PointDeVente'
import Factures from './pages/admin/Factures'
import ProductDetails from './pages/admin/ProductDetails'
import Packs from './pages/admin/Packs'
import Parametres from './pages/admin/Parametres'
import MouvementsStock from './pages/admin/MouvementsStock'
import CategoryProducts from './pages/admin/CategoryProducts'
import Marques from './pages/admin/Marques'
import ClientProfile from './pages/admin/ClientProfile'
import Familles from './pages/admin/Familles'

function RootRedirect() {
  const { user, loading, hasAnyPermission } = useAuth()
  if (loading) return <div className="page">Loading…</div>

  if (user) {
    if (hasAnyPermission(['produits.view', 'produits.create', 'produits.edit'])) return <Navigate to="/admin/produits" replace />
    if (hasAnyPermission(['categories.view', 'categories.manage'])) return <Navigate to="/admin/familles" replace />
    return <Navigate to="/admin/account" replace />
  }

  return <Navigate to="/login" replace />
}

function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route path="/" element={<RootRedirect />} />
        <Route path="/acount" element={<Navigate to="/admin/account" replace />} />
        <Route path="/login" element={<Login />} />
        <Route path="/admin" element={<AdminLayout />}>
          <Route index element={<Navigate to="produits" replace />} />
          <Route path="account" element={<Account />} />
          <Route path="acount" element={<Navigate to="/admin/account" replace />} />
          <Route path="dashboard" element={<Dashboard />} />
          <Route path="produits" element={<Produits />} />
          <Route path="produits/:id" element={<ProductDetails />} />
          <Route path="familles" element={<Familles />} />
          <Route path="familles/:familleId/categories" element={<Categories />} />
          <Route path="categories" element={<Categories />} />
          <Route path="categories/:categorieId" element={<SousCategories />} />
          <Route path="sous_categories/:sousCategorieId/articles" element={<Articles />} />
          <Route path="marques" element={<Marques />} />

          {/* ── GESTION DE TRAVAIL ── */}
          <Route path="fournisseurs" element={<Fournisseurs />} />
          <Route path="clients" element={<Clients />} />
          <Route path="clients/:clientId/profile" element={<ClientProfile />} />
          <Route path="stock" element={<Stock />} />
          <Route path="mouvements-stock" element={<MouvementsStock />} />
          <Route path="mouvements-stock/entree" element={<EntreeStock />} />
          <Route path="mouvements-stock/sortie" element={<SortieStock />} />
          <Route path="ventes" element={<Ventes />} />
          <Route path="pos" element={<PointDeVente />} />
          <Route path="factures" element={<Factures />} />
          <Route path="prix" element={<Prix />} />

          {/* ── GESTION ÉQUIPE ── */}
          <Route path="utilisateurs" element={<Utilisateurs />} />
          <Route path="packs" element={<Packs />} />
          <Route path="roles" element={<Roles />} />
          <Route path="promotions" element={<Promotions />} />

          {/* ── SYSTÈME ── */}
          <Route path="statistiques" element={<Placeholder title="Statistiques" subtitle="Aperçu des stats" />} />
          <Route path="parametres" element={<Parametres />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AuthProvider>
  )
}

export default App
