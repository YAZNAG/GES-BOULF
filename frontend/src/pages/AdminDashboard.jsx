import { useState } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuth } from '../auth/authContext'

export default function AdminDashboard() {
  const { user, loading, logout } = useAuth()
  const [query, setQuery] = useState('')
  const [category, setCategory] = useState('all')
  const [view, setView] = useState('grid')

  const categories = [
    { id: 'all', label: 'Toutes catégories' },
    { id: 'rices', label: 'Rices' },
    { id: 'pates', label: 'Pâtes' },
    { id: 'huiles', label: 'Huiles' },
    { id: 'conserves', label: 'Conserves' },
  ]

  const products = [
    { id: 1, nom: 'pasta', categorie: 'rices', unite: 'kg', poids: 125, prix: 30, img: '/imagelogin.png' },
    { id: 2, nom: 'pasta', categorie: 'rices', unite: 'kg', poids: 125, prix: 30, img: '/imagelogin.png' },
    { id: 3, nom: 'pasta', categorie: 'rices', unite: 'kg', poids: 125, prix: 30, img: '/imagelogin.png' },
    { id: 4, nom: 'tomates', categorie: 'conserves', unite: 'pièce', poids: 0, prix: 8.5, img: '/imagelogin.png' },
    { id: 5, nom: 'huile', categorie: 'huiles', unite: 'L', poids: 5, prix: 95, img: '/imagelogin.png' },
    { id: 6, nom: 'spaghetti', categorie: 'pates', unite: 'kg', poids: 1, prix: 12, img: '/imagelogin.png' },
  ]

  const q = query.trim().toLowerCase()
  const filtered = products.filter((p) => {
    const okCategory = category === 'all' ? true : p.categorie === category
    const okQuery = !q ? true : p.nom.toLowerCase().includes(q)
    return okCategory && okQuery
  })

  if (loading) return <div className="page">Loading…</div>

  if (!user) return <Navigate to="/login" replace />

  if ((user?.role?.nom || '') !== 'admin') return <Navigate to="/login" replace />

  return (
    <div className="admin-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark">
            <span className="brand-mark-dot" />
          </div>
          <div>
            <div className="brand-title">El Herri</div>
            <div className="brand-sub">Management Portal</div>
          </div>
        </div>

        <div className="nav-section">
          <div className="nav-title">MENU PRINCIPAL</div>
          <button className="nav-item nav-item-active" type="button">
            <span className="nav-icon" />
            Dashboard
          </button>
          <button className="nav-item" type="button">
            <span className="nav-icon" />
            Commandes
          </button>
          <button className="nav-item" type="button">
            <span className="nav-icon" />
            Produits
          </button>
          <button className="nav-item" type="button">
            <span className="nav-icon" />
            Catégories
          </button>
        </div>

        <div className="nav-section">
          <div className="nav-title">GESTION ÉQUIPE</div>
          <button className="nav-item" type="button">
            <span className="nav-icon" />
            Utilisateurs
          </button>
          <button className="nav-item" type="button">
            <span className="nav-icon" />
            Agents
          </button>
          <button className="nav-item" type="button">
            <span className="nav-icon" />
            Rôles &amp; Permissions
          </button>
          <button className="nav-item" type="button">
            <span className="nav-icon" />
            Promotions
          </button>
        </div>

        <div className="nav-section">
          <div className="nav-title">SYSTÈME</div>
          <button className="nav-item" type="button">
            <span className="nav-icon" />
            Statistiques
          </button>
          <button className="nav-item" type="button">
            <span className="nav-icon" />
            Paramètres
          </button>
        </div>

        <div className="sidebar-footer">
          <button className="logout" type="button" onClick={logout}>
            Déconnexion
          </button>
        </div>
      </aside>

      <main className="admin-main">
        <header className="topbar">
          <div className="topbar-search">
            <span className="topbar-search-ico" />
            <input
              className="topbar-search-input"
              placeholder="Rechercher des commandes, produits ou clients..."
              value={query}
              onChange={(e) => setQuery(e.target.value)}
            />
          </div>

          <div className="topbar-actions">
            <button className="icon-btn" type="button" aria-label="Notifications">
              <span className="bell" />
            </button>
            <div className="user-chip">
              <div className="avatar">{(user?.prenom?.[0] || 'A').toUpperCase()}</div>
              <div className="user-chip-text">
                <div className="user-chip-name">{`${user?.nom || ''} ${user?.prenom || ''}`.trim()}</div>
                <div className="user-chip-role">Super Admin</div>
              </div>
              <span className="chev" />
            </div>
          </div>
        </header>

        <section className="content">
          <div className="page-head">
            <div>
              <div className="page-title">Produits</div>
              <div className="page-subtitle">Gérer le catalogue de produits</div>
            </div>
            <button className="primary" type="button">
              + Ajouter Produit
            </button>
          </div>

          <div className="toolbar">
            <div className="toolbar-left">
              <div className="tool-search">
                <span className="tool-search-ico" />
                <input
                  className="tool-search-input"
                  placeholder="Rechercher un produit..."
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                />
              </div>

              <select className="tool-select" value={category} onChange={(e) => setCategory(e.target.value)}>
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.label}
                  </option>
                ))}
              </select>
            </div>

            <div className="toolbar-right">
              <button
                className={`view-btn ${view === 'grid' ? 'view-btn-active' : ''}`}
                type="button"
                onClick={() => setView('grid')}
                aria-label="Vue grille"
              />
              <button
                className={`view-btn view-btn-list ${view === 'list' ? 'view-btn-active' : ''}`}
                type="button"
                onClick={() => setView('list')}
                aria-label="Vue liste"
              />
            </div>
          </div>

          <div className={`grid ${view === 'list' ? 'grid-list' : ''}`}>
            {filtered.map((p) => (
              <div key={p.id} className="card">
                <div className="card-badge">{p.poids ? `${p.poids} ${p.unite}` : p.unite}</div>
                <div className="card-img">
                  <img src={p.img} alt="" />
                </div>
                <div className="card-body">
                  <div className="card-name">{p.nom}</div>
                  <div className="card-cat">{p.categorie}</div>
                  <div className="card-foot">
                    <div className="card-price">
                      {p.prix} DH/{p.unite}
                    </div>
                    <div className="card-actions">
                      <button className="mini" type="button" aria-label="Edit">
                        <span className="pen" />
                      </button>
                      <button className="mini mini-danger" type="button" aria-label="Delete">
                        <span className="trash" />
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </section>
      </main>
    </div>
  )
}
