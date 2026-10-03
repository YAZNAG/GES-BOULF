import { Bell } from 'lucide-react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { apiFetch } from '../../lib/api'
import { toast } from '../../lib/toast'
import { useAuth } from '../../auth/authContext'

function formatWhen(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ''
  const pad = (n) => String(n).padStart(2, '0')
  return `${pad(d.getDate())}/${pad(d.getMonth() + 1)} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

function labelAction(it) {
  const action = (it?.action || '').toString()
  const table = (it?.table_cible || '').toString()
  const who = it?.utilisateur ? `${it.utilisateur.nom || ''} ${it.utilisateur.prenom || ''}`.trim() : 'Système'
  if (!action && !table) return 'Notification'
  if (!table) return `${who} • ${action}`
  return `${who} • ${action} • ${table}`
}

export default function NotificationBell() {
  const { hasPermission } = useAuth()
  const [open, setOpen] = useState(false)
  const [loading, setLoading] = useState(false)
  const [items, setItems] = useState([])
  const [error, setError] = useState('')
  const ref = useRef(null)

  const lastSeenKey = 'gs_notif_seen_at'
  const seenAt = useMemo(() => {
    const raw = localStorage.getItem(lastSeenKey)
    const d = raw ? new Date(raw) : null
    return d && !Number.isNaN(d.getTime()) ? d : null
  }, [])

  const unread = useMemo(() => {
    if (!seenAt) return items.length
    return items.filter((it) => {
      const d = it?.created_at ? new Date(it.created_at) : null
      if (!d || Number.isNaN(d.getTime())) return false
      return d.getTime() > seenAt.getTime()
    }).length
  }, [items, seenAt])

  async function load() {
    setLoading(true)
    setError('')
    try {
      const res = await apiFetch('/api/admin/notifications?limit=12')
      const list = Array.isArray(res?.data) ? res.data : res?.data?.data || []
      setItems(list)
    } catch (e) {
      setError(e?.message || 'Erreur')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (!hasPermission('systeme.stats')) return
    load()
    const t = window.setInterval(load, 20000)
    return () => window.clearInterval(t)
  }, [hasPermission])

  useEffect(() => {
    function onDocClick(e) {
      if (!ref.current) return
      if (!ref.current.contains(e.target)) setOpen(false)
    }
    document.addEventListener('mousedown', onDocClick)
    return () => document.removeEventListener('mousedown', onDocClick)
  }, [])

  useEffect(() => {
    if (!open) return
    const nowIso = new Date().toISOString()
    localStorage.setItem(lastSeenKey, nowIso)
  }, [open])

  function toggle() {
    setOpen((v) => !v)
    if (!open) load()
  }

  function retry() {
    load()
    if (error) toast({ type: 'error', message: error })
  }

  if (!hasPermission('systeme.stats')) return null

  return (
    <div className="notif" ref={ref}>
      <button className="icon-btn notif-btn" type="button" aria-label="Notifications" onClick={toggle}>
        <Bell size={18} color="#64748b" />
        {unread > 0 ? <span className="notif-dot">{unread > 9 ? '9+' : unread}</span> : null}
      </button>

      {open ? (
        <div className="notif-menu">
          <div className="notif-head">
            <div className="notif-title">Notifications</div>
            <button className="notif-reload" type="button" onClick={retry} disabled={loading}>
              Actualiser
            </button>
          </div>

          {loading ? <div className="notif-empty">Loading…</div> : null}
          {!loading && error ? <div className="notif-empty">{error}</div> : null}
          {!loading && !error && items.length === 0 ? <div className="notif-empty">Aucune notification</div> : null}

          {!loading && !error && items.length ? (
            <div className="notif-list">
              {items.map((it) => (
                <div key={it.id} className="notif-item">
                  <div className="notif-item-top">
                    <div className="notif-item-title">{labelAction(it)}</div>
                    <div className="notif-item-time">{formatWhen(it.created_at)}</div>
                  </div>
                  {it?.details ? <div className="notif-item-sub">{JSON.stringify(it.details)}</div> : null}
                </div>
              ))}
            </div>
          ) : null}
        </div>
      ) : null}
    </div>
  )
}
