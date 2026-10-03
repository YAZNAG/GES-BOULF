import { useState } from 'react'
import { useAuth } from '../../auth/authContext'
import Alert from '../../components/Alert'
import '../../styles/account.css'

export default function Account() {
  const { user, updateProfile } = useAuth()

  const [nom, setNom] = useState(user?.nom || '')
  const [prenom, setPrenom] = useState(user?.prenom || '')
  const [email, setEmail] = useState(user?.email || '')
  const [password, setPassword] = useState('')
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')

  async function onSubmit(e) {
    e.preventDefault()
    setMessage('')
    setError('')
    setSaving(true)

    try {
      await updateProfile({
        nom: nom.trim(),
        prenom: prenom.trim(),
        email: email.trim(),
        mot_de_passe: password || undefined,
      })
      setPassword('')
      setMessage('Profil mis à jour')
    } catch (err) {
      setError(err?.message || 'Erreur')
    } finally {
      setSaving(false)
    }
  }

  return (
    <section className="content-account">
      <div className="page-head">
        <div>
          <div className="page-title">Mon compte</div>
          <div className="page-subtitle">Modifier vos informations</div>
        </div>
      </div>

      <div className="account-card">
        <form className="account-form" onSubmit={onSubmit}>
          <div className="form-grid">
            <label className="form-label">
              Nom
              <input className="form-input" value={nom} onChange={(e) => setNom(e.target.value)} />
            </label>
            <label className="form-label">
              Prénom
              <input className="form-input" value={prenom} onChange={(e) => setPrenom(e.target.value)} />
            </label>
          </div>

          <label className="form-label">
            Email
            <input className="form-input" type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
          </label>

          <label className="form-label">
            Nouveau mot de passe
            <input
              className="form-input form-input-muted"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Laisser vide si inchangé"
            />
          </label>

          <Alert type="success" message={message} />
          <Alert type="error" message={error} />

          <div className="account-actions">
            <button className="btn-primary" type="submit" disabled={saving}>
              {saving ? 'Enregistrement…' : 'Enregistrer'}
            </button>
          </div>
        </form>
      </div>
    </section>
  )
}
