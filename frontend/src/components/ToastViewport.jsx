import { useEffect, useRef, useState } from 'react'
import { subscribe } from '../lib/toast'

export default function ToastViewport() {
  const [items, setItems] = useState([])
  const timers = useRef(new Map())

  useEffect(() => {
    const timersMap = timers.current
    function onEvent(ev) {
      if (ev?.type !== 'add' || !ev.item) return
      const item = ev.item

      setItems((prev) => {
        const next = [...prev, item]
        return next.length > 4 ? next.slice(next.length - 4) : next
      })

      const t = window.setTimeout(() => {
        setItems((prev) => prev.filter((x) => x.id !== item.id))
        timersMap.delete(item.id)
      }, Math.max(800, item.timeout))
      timersMap.set(item.id, t)
    }

    const unsub = subscribe(onEvent)
    return () => {
      unsub()
      for (const t of timersMap.values()) window.clearTimeout(t)
      timersMap.clear()
    }
  }, [])

  function close(id) {
    const t = timers.current.get(id)
    if (t) window.clearTimeout(t)
    timers.current.delete(id)
    setItems((prev) => prev.filter((x) => x.id !== id))
  }

  if (!items.length) return null

  return (
    <div className="toast-viewport" aria-live="polite" aria-relevant="additions removals">
      {items.map((it) => {
        const tone = it.type === 'success' ? 'banner-ok' : 'banner-err'
        const className = ['toast-item', 'banner', tone].join(' ')
        return (
          <div key={it.id} className={className}>
            <div className="toast-text">{it.message}</div>
            <button className="toast-x" type="button" onClick={() => close(it.id)} aria-label="Fermer">
              ×
            </button>
          </div>
        )
      })}
    </div>
  )
}

