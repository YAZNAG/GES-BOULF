export const TOKEN_KEY = 'gs_token'

const API_BASE = 'http://localhost:8000'

export function getToken() {
  return localStorage.getItem(TOKEN_KEY)
}

export function setToken(token) {
  if (!token) {
    localStorage.removeItem(TOKEN_KEY)
    return
  }
  localStorage.setItem(TOKEN_KEY, token)
}

export async function apiFetch(path, options = {}) {
  const token = getToken()
  const headers = new Headers(options.headers || {})

  if (!headers.has('Accept')) headers.set('Accept', 'application/json')

  if (token && token !== 'fake-token') headers.set('Authorization', `Bearer ${token}`)

  const url = `${API_BASE}${path.startsWith('/') ? path : `/${path}`}`

  const res = await fetch(url, {
    ...options,
    headers,
  })

  const contentType = res.headers.get('content-type') || ''
  const isJson = contentType.includes('application/json')
  const payload = isJson ? await res.json().catch(() => null) : await res.text()

  if (!res.ok) {
    let message =
      (payload && typeof payload === 'object' && payload.message) ||
      `HTTP ${res.status}`

    if (res.status === 422 && payload && typeof payload === 'object') {
      const errors = payload.errors && typeof payload.errors === 'object' ? payload.errors : null
      if (errors) {
        const firstField = Object.keys(errors)[0]
        const firstMsg = Array.isArray(errors[firstField]) ? errors[firstField][0] : errors[firstField]
        if (firstMsg) message = String(firstMsg)
      }
    }

    if (typeof message === 'string' && (message.includes('SQLSTATE[23000]') || message.includes('Integrity constraint violation'))) {
      message = "Impossible d'effectuer cette opération : cet élément est lié à d'autres enregistrements."
    }

    const err = new Error(message)
    err.status = res.status
    err.payload = payload
    throw err
  }

  return payload
}

