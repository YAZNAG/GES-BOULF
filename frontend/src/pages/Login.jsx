import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Eye, EyeOff, Lock, Mail } from 'lucide-react'
import { useAuth } from '../auth/authContext'

/** Connexion : logo, e-mail, mot de passe et bouton — rien d'autre. */
export default function Login() {
  const { login } = useAuth()
  const navigate = useNavigate()

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [show, setShow] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState('')

  async function onSubmit(e) {
    e.preventDefault()
    setError('')
    setSubmitting(true)
    try {
      const user = await login({ email: email.trim(), password })
      if ((user?.role?.nom || '') !== 'admin') {
        setError('Accès réservé aux administrateurs.')
        return
      }
      navigate('/admin', { replace: true })
    } catch (err) {
      setError(err?.message || 'Connexion impossible.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="lg-page">
      <div className="lg-glow" aria-hidden />
      <form className="lg-card" onSubmit={onSubmit}>
        <img className="lg-logo" src="/logo-boulfrik.png" alt="Boulfrik" width="76" height="76" />
        <h1 className="lg-brand">Boulfrik</h1>

        <label className="lg-field">
          <Mail size={18} />
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="Adresse e-mail"
            autoComplete="email"
            autoFocus
            required
          />
        </label>

        <label className="lg-field">
          <Lock size={18} />
          <input
            type={show ? 'text' : 'password'}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Mot de passe"
            autoComplete="current-password"
            required
          />
          <button type="button" className="lg-eye" onClick={() => setShow((s) => !s)} aria-label={show ? 'Masquer le mot de passe' : 'Afficher le mot de passe'}>
            {show ? <EyeOff size={18} /> : <Eye size={18} />}
          </button>
        </label>

        {error ? <div className="lg-error">{error}</div> : null}

        <button className="lg-submit" type="submit" disabled={submitting}>
          {submitting ? <span className="lg-spinner" aria-hidden /> : null}
          {submitting ? 'Connexion…' : 'Se connecter'}
        </button>
      </form>
    </div>
  )
}
