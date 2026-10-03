import { useState, useEffect } from 'react'

export function useParametres() {
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [settings, setSettings] = useState(() => {
    // Try loading from localStorage first to mock real implementation
    const saved = localStorage.getItem('app_settings')
    if (saved) return JSON.parse(saved)
    return {
      nom_entreprise: 'Mon Magasin PRO',
      devise: 'MAD',
      adresse: 'Bvd Hassan II, Casablanca',
      telephone: '+212 600 000 000',
      email_contact: 'contact@magasin.com',
      tva_default: 20,
      invoice_prefix: 'FAC-',
      invoice_notes: 'Merci pour votre confiance.',
      notify_email: true,
      notify_sms: false,
      stock_alert: 10,
      mfa_enabled: false,
      session_timeout: 120,
      max_login_attempts: 5
    }
  })

  // Mock API Loading
  useEffect(() => {
    setTimeout(() => {
      setLoading(false)
    }, 400)
  }, [])

  function updateSettings(newSettings) {
    setSubmitting(true)
    // Mock API Save
    setTimeout(() => {
      setSettings(newSettings)
      localStorage.setItem('app_settings', JSON.stringify(newSettings))
      setSubmitting(false)
    }, 500)
  }

  return {
    settings,
    loading,
    submitting,
    updateSettings
  }
}
