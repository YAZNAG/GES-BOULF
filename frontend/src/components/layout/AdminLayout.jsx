import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useState } from 'react'
import { useAuth } from '../../auth/authContext'
import ToastViewport from '../ToastViewport'
import Sidebar from './Sidebar'
import Topbar from './Topbar'

export default function AdminLayout() {
  const { user, loading, logout } = useAuth()
  const location = useLocation()
  const [search, setSearch] = useState('')
  const [sidebarOpen, setSidebarOpen] = useState(window.innerWidth > 900)

  if (loading) return <div className="page">Loading…</div>

  if (!user) return <Navigate to="/login" replace state={{ from: location }} />

  return (
    <div className="admin-shell">
      <div
        className={sidebarOpen ? 'sidebar-overlay sidebar-overlay-open' : 'sidebar-overlay'}
        onClick={() => setSidebarOpen(false)}
      />
      <Sidebar open={sidebarOpen} onClose={() => setSidebarOpen(false)} onLogout={logout} />
      <main className="admin-main">
        <Topbar
          user={user}
          search={search}
          onSearchChange={setSearch}
          onLogout={logout}
          onToggleSidebar={() => setSidebarOpen((v) => !v)}
          sidebarOpen={sidebarOpen}
          
        />
        <Outlet context={{ search, setSearch }} />
      </main>
      <ToastViewport />
    </div>
  )
}
