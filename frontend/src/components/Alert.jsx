import { useMemo } from 'react'

export default function Alert({ type = 'error', message }) {
  const text = (message || '').toString()
  const tone = type === 'success' ? 'banner-ok' : type === 'error' ? 'banner-err' : ''
  const className = useMemo(() => ['banner', tone].filter(Boolean).join(' '), [tone])

  if (!text) return null
  return <div className={className}>{text}</div>
}
