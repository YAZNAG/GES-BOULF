import { useCallback, useEffect, useMemo, useState } from 'react'
import { apiFetch, getToken, setToken } from '../lib/api'
import { AuthContext } from './authContext'

const USER_KEY = 'gs_user'
const FAKE_TOKEN = 'fake-token'

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    const raw = localStorage.getItem(USER_KEY)
    if (!raw) return null
    try {
      return JSON.parse(raw)
    } catch {
      return null
    }
  })
  const [loading, setLoading] = useState(true)

  const refresh = useCallback(async () => {
    const token = getToken()
    const raw = localStorage.getItem(USER_KEY)

    if (!token || !raw) {
      setUser(null)
      setLoading(false)
      return
    }

    if (token === FAKE_TOKEN) {
      setToken(null)
      localStorage.removeItem(USER_KEY)
      setUser(null)
      setLoading(false)
      return
    }

    try {
      const data = await apiFetch('/api/auth/me')
      localStorage.setItem(USER_KEY, JSON.stringify(data.user))
      setUser(data.user)
    } catch {
      setToken(null)
      localStorage.removeItem(USER_KEY)
      setUser(null)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    refresh()
  }, [refresh])

  const login = useCallback(async ({ email, password }) => {
    if (!email) throw new Error('Email requis')
    if (!password) throw new Error('Mot de passe requis')
    const data = await apiFetch('/api/auth/login', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email, password }),
    })

    setToken(data.token)
    localStorage.setItem(USER_KEY, JSON.stringify(data.user))
    setUser(data.user)
    return data.user
  }, [])

  const logout = useCallback(async () => {
    const token = getToken()

    if (token && token !== FAKE_TOKEN) {
      try {
        await apiFetch('/api/auth/logout', { method: 'POST' })
      } catch (e) {
        void e
      }
    }

    setToken(null)
    localStorage.removeItem(USER_KEY)
    setUser(null)
  }, [])

  const updateProfile = useCallback(
    async ({ nom, prenom, email, mot_de_passe }) => {
      if (!user) throw new Error('Not logged in')

      const token = getToken()

      if (!token || token === FAKE_TOKEN) {
        throw new Error('Session expirée. Reconnecte-toi.')
      }

      const payload = {}
      if (nom != null) payload.nom = nom
      if (prenom != null) payload.prenom = prenom
      if (email != null) payload.email = email
      if (mot_de_passe) payload.mot_de_passe = mot_de_passe

      const updated = await apiFetch(`/api/utilisateurs/${user.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })

      localStorage.setItem(USER_KEY, JSON.stringify(updated))
      setUser(updated)
      return updated
    },
    [user]
  )

  const value = useMemo(
    () => ({
      user,
      loading,
      login,
      logout,
      refresh,
      updateProfile,
      hasPermission: (key) => {
        const perm = (key || '').toString()
        if (!perm) return true
        const roleName = (user?.role?.nom || '').toString().toLowerCase()
        if (roleName === 'admin') return true
        const list = Array.isArray(user?.role?.permissions) ? user.role.permissions.map(String) : []
        return list.includes(perm)
      },
      hasAnyPermission: (keys) => {
        const roleName = (user?.role?.nom || '').toString().toLowerCase()
        if (roleName === 'admin') return true
        const list = Array.isArray(user?.role?.permissions) ? user.role.permissions.map(String) : []
        const arr = Array.isArray(keys) ? keys : []
        return arr.some((k) => list.includes(String(k)))
      },
    }),
    [user, loading, login, logout, refresh, updateProfile]
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
