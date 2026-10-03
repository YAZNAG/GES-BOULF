import { useState } from "react";
import { NavLink } from "react-router-dom";
import {
  ArrowDown,
  ArrowLeftRight,
  ArrowRight,
  BarChart3,
  Boxes,
  Building2,
  CircleDollarSign,
  LayoutDashboard,
  PackageSearch,
  Receipt,
  Settings,
  ShoppingCart,
  Tags,
  Truck,
  UserCog,
  Users,
  Warehouse,
  X,
  User,
  Package,
  Monitor,
  FileText,
  Tag,
} from "lucide-react";
import { useAuth } from "../../auth/authContext";

export default function Sidebar({ open, onClose, onLogout }) {
  const [openSub, setOpenSub] = useState(null);
  const { hasAnyPermission, hasPermission } = useAuth();

  const navItemClass = ({ isActive }) =>isActive ? "nav-item nav-item-active" : "nav-item";

  function close() {
    onClose?.();
  }

  function toggleSub(key) {
    setOpenSub((prev) => (prev === key ? null : key));
  }

  return (
    <aside className={open ? "sidebar sidebar-open" : "sidebar"}>
      <div className="brand">
        <div className="brand-mark">
          <img className="brand-logo" src="/logo.png" alt="Logo" />
        </div>
        <div>
          <div className="brand-title">El Herri</div>
          <div className="brand-sub">Management Portal</div>
        </div>
        <button
          className="sidebar-close"
          type="button"
          onClick={close}
          aria-label="Fermer"
        >
          <X size={18} />
        </button>
      </div>

      <div className="sidebar-nav">
        {/* ── DASHBOARD ── */}
        <div className="nav-section">
          {hasPermission("systeme.stats") ? (
            <NavLink
              className={navItemClass}
              to="/admin/dashboard"
            >
              <LayoutDashboard className="nav-icon" size={18} />
              Dashboard
            </NavLink>
          ) : null}
        </div>

        {/* ── VENTES — المبيعات ── */}
        <div className="nav-section">
          <div className="nav-title">VENTES — المبيعات</div>
          <NavLink className={navItemClass} to="/admin/ventes">
            <Receipt className="nav-icon" size={18} />
            Ventes
          </NavLink>
          <NavLink className={navItemClass} to="/admin/pos">
            <Monitor className="nav-icon" size={18} />
            Point de Vente
          </NavLink>
          <NavLink className={navItemClass} to="/admin/factures">
            <FileText className="nav-icon" size={18} />
            Factures
          </NavLink>
          {hasAnyPermission(["promotions.view", "promotions.manage"]) ? (
            <NavLink
              className={navItemClass}
              to="/admin/promotions"
            >
              <Tags className="nav-icon" size={18} />
              Promotions
            </NavLink>
          ) : null}
          {hasAnyPermission(["packs.view", "packs.manage"]) ? (
            <NavLink className={navItemClass} to="/admin/packs">
              <Package className="nav-icon" size={18} />
              Packs
            </NavLink>
          ) : null}
        </div>

        {/* ── PRODUITS — المنتجات ── */}
        <div className="nav-section">
          <div className="nav-title">PRODUITS — المنتجات</div>
          {hasAnyPermission([
            "produits.view",
            "produits.create",
            "produits.edit",
          ]) ? (
            <NavLink
              className={navItemClass}
              to="/admin/produits"
            >
              <Boxes className="nav-icon" size={18} />
              Produits
            </NavLink>
          ) : null}
          {hasAnyPermission(["categories.view", "categories.manage"]) ? (
            <NavLink
              className={navItemClass}
              to="/admin/familles"
            >
              <PackageSearch className="nav-icon" size={18} />
              Familles Catégories
            </NavLink>
          ) : null}
          <NavLink className={navItemClass} to="/admin/marques">
            <Tag className="nav-icon" size={18} />
            Marques
          </NavLink>
          <NavLink className={navItemClass} to="/admin/prix">
            <CircleDollarSign className="nav-icon" size={18} />
            Prix
          </NavLink>
        </div>

        {/* ── STOCK — المخزون ── */}
        <div className="nav-section">
          <div className="nav-title">STOCK — المخزون</div>
          <NavLink className={navItemClass} to="/admin/stock">
            <Warehouse className="nav-icon" size={18} />
            Stock
          </NavLink>
          {/* ── Mouvement de Stock (dropdown) ── */}
          <button
            className={`nav-item nav-parent ${openSub === "mouvement" ? "nav-parent-open" : ""}`}
            type="button"
            onClick={() => toggleSub("mouvement")}
          >
            <ArrowLeftRight className="nav-icon" size={18} />
            Mouvement de Stock
          </button>
          <div
            className={`nav-sub ${openSub === "mouvement" ? "nav-sub-open" : ""}`}
          >
            <NavLink
              className={navItemClass}
              to="/admin/mouvements-stock"
              end
            >
              <ArrowRight className="nav-icon" size={18} />
              Historique
            </NavLink>
            <NavLink
              className={navItemClass}
              to="/admin/mouvements-stock/entree"
            >
              <ArrowRight className="nav-icon" size={18} />
              Entrée
            </NavLink>
            <NavLink
              className={navItemClass}
              to="/admin/mouvements-stock/sortie"
            >
              <ArrowRight className="nav-icon" size={18} />
              Sortie
            </NavLink>
          </div>
        </div>

        {/* ── PERSONNES — الأشخاص ── */}
        <div className="nav-section">
          <div className="nav-title">PERSONNES — الأشخاص</div>
          <NavLink className={navItemClass} to="/admin/clients">
            <User className="nav-icon" size={18} />
            Clients
          </NavLink>
          <NavLink
            className={navItemClass}
            to="/admin/fournisseurs"
          >
            <Building2 className="nav-icon" size={18} />
            Fournisseurs
          </NavLink>
        </div>

        {/* ── SYSTÈME — النظام ── */}
        <div className="nav-section">
          <div className="nav-title">SYSTÈME — النظام</div>
          {hasAnyPermission(["utilisateurs.view", "utilisateurs.manage"]) ? (
            <NavLink
              className={navItemClass}
              to="/admin/utilisateurs"
            >
              <Users className="nav-icon" size={18} />
              Utilisateurs
            </NavLink>
          ) : null}
          {hasPermission("systeme.settings") ? (
            <NavLink className={navItemClass} to="/admin/roles">
              <UserCog className="nav-icon" size={18} />
              Rôles &amp; Permissions
            </NavLink>
          ) : null}
          <NavLink
            className={navItemClass}
            to="/admin/parametres"
          >
            <Settings className="nav-icon" size={18} />
            Paramètres
          </NavLink>
        </div>
      </div>

      <div className="sidebar-footer">
        <button
          className="logout"
          type="button"
          onClick={() => {
            close();
            onLogout?.();
          }}
        >
          Déconnexion
        </button>
      </div>
    </aside>
  );
}
