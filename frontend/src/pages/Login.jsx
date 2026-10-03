import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../auth/authContext'

export default function Login() {
  const { login } = useAuth()
  const navigate = useNavigate()

  const [email, setEmail] = useState('admin@elherii.ma')
  const [password, setPassword] = useState('password')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState('')

  async function onSubmit(e) {
    e.preventDefault()
    setError('')
    setSubmitting(true)

    try {
      const user = await login({ email, password })
      if ((user?.role?.nom || '') !== 'admin') {
        setError('Accès réservé aux administrateurs')
        return
      }
      navigate('/admin', { replace: true })
    } catch (err) {
      setError(err?.message || 'Erreur de connexion')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="auth-layout">
      <div className="auth-visual">
        <img className="auth-image" src="/imagelogin.png" alt="" />
      </div>

      <div className="auth-panel">
        <div className="auth-card">
          <h1 className="auth-title">Connexion Admin</h1>
          <p className="auth-subtitle">
            Accédez à votre tableau de bord et pilotez l’activité de votre stock.
          </p>

          <form className="auth-form" onSubmit={onSubmit}>
            <label className="auth-label">
              Email
              <input
                className="auth-input"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@example.com"
                autoComplete="email"
                required
              />
            </label>

            <label className="auth-label">
              Mot de passe
              <input
                className="auth-input"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                autoComplete="current-password"
                required
              />
            </label>

            {error ? <div className="auth-error">{error}</div> : null}

            <button className="auth-button" type="submit" disabled={submitting}>
              {submitting ? 'Connexion…' : 'Se connecter'}
            </button>

            <div className="auth-foot">
              <span>Accès réservé aux administrateurs</span>
            </div>
          </form>
        </div>
      </div>
    </div>
  )
}
