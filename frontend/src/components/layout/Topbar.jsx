import { ChevronDown, LogOut, Menu, Search, Settings2, User, X } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import NotificationBell from '../notifications/NotificationBell'

export default function Topbar({ user, search, onSearchChange, onLogout, onToggleSidebar,sidebarOpen }) {
  const [open, setOpen] = useState(false)
  const ref = useRef(null)

  useEffect(() => {
    function onDocClick(e) {
      if (!ref.current) return
      if (!ref.current.contains(e.target)) setOpen(false)
    }

    document.addEventListener('mousedown', onDocClick)
    return () => document.removeEventListener('mousedown', onDocClick)
  }, [])

  return (
    <header className="topbar">
      <button className="icon-btn icon-btn-menu" type="button" onClick={onToggleSidebar} aria-label="Menu">
        {sidebarOpen ? <X size={18} color="#64748b" /> : <Menu size={18} color="#64748b" />}
      </button>
      <div className="topbar-actions">
        <NotificationBell />
        <div className="account" ref={ref}>
          <button className="user-chip" type="button" onClick={() => setOpen((v) => !v)}>
            <div className="avatar">
              <User size={18} />
            </div>
            <div className="user-chip-text">
              <div className="user-chip-name">{`${user?.nom || ''} ${user?.prenom || ''}`.trim()}</div>
              <div className="user-chip-role">Super Admin</div>
            </div>
            <ChevronDown size={16} color="#94a3b8" />
          </button>

          {open ? (
            <div className="account-menu">
              <Link className="account-item" to="/admin/account" onClick={() => setOpen(false)}>
                <Settings2 size={16} />
                Mon compte
              </Link>
              <button
                className="account-item account-item-danger"
                type="button"
                onClick={() => {
                  setOpen(false)
                  onLogout?.()
                }}
              >
                <LogOut size={16} />
                Déconnexion
              </button>
            </div>
          ) : null}
        </div>
      </div>
    </header>
  )
}
