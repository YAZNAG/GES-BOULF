import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from 'react'
import { Barcode, Loader2, Search } from 'lucide-react'
import { apiFetch } from '../../lib/api'
import { toast } from '../../lib/toast'

const isCode = (s) => /^\d{6,14}$/.test(s)

/**
 * Champ unique pour scanner un code-barres ou chercher un article.
 * - Lecteur code-barres (ou saisie + Entrée) : recherche exacte par code → onPick(article).
 * - Texte : suggestions (nom, marque, code) au fil de la frappe.
 * Le champ garde le focus après chaque ajout pour enchaîner les scans.
 */
const ArticleSearch = forwardRef(function ArticleSearch({ onPick, placeholder, filtre = '', autoFocus = true }, ref) {
  const [q, setQ] = useState('')
  const [items, setItems] = useState([])
  const [open, setOpen] = useState(false)
  const [active, setActive] = useState(0)
  const [busy, setBusy] = useState(false)
  const input = useRef(null)
  const seq = useRef(0)

  useImperativeHandle(ref, () => ({ focus: () => input.current?.focus() }))

  useEffect(() => {
    const s = q.trim()
    if (s.length < 2 || isCode(s)) {
      setItems([])
      return undefined
    }
    const id = ++seq.current
    const t = setTimeout(async () => {
      try {
        const res = await apiFetch(`/api/articles?per_page=8&q=${encodeURIComponent(s)}${filtre}`)
        if (id !== seq.current) return
        setItems(res?.data || [])
        setActive(0)
        setOpen(true)
      } catch {
        /* recherche silencieuse */
      }
    }, 220)
    return () => clearTimeout(t)
  }, [q, filtre])

  function pick(article) {
    onPick(article)
    setQ('')
    setItems([])
    setOpen(false)
    requestAnimationFrame(() => input.current?.focus())
  }

  async function lookup(code) {
    setBusy(true)
    try {
      pick(await apiFetch(`/api/articles/lookup?code=${encodeURIComponent(code)}`))
    } catch (e) {
      toast({ type: 'error', message: e?.message || `Code ${code} introuvable.` })
      setQ('')
    } finally {
      setBusy(false)
    }
  }

  function onKeyDown(e) {
    if (e.key === 'ArrowDown' && items.length) {
      e.preventDefault()
      setActive((a) => Math.min(items.length - 1, a + 1))
    } else if (e.key === 'ArrowUp' && items.length) {
      e.preventDefault()
      setActive((a) => Math.max(0, a - 1))
    } else if (e.key === 'Enter') {
      e.preventDefault()
      const s = q.trim()
      if (!s) return
      if (isCode(s)) lookup(s)
      else if (items[active]) pick(items[active])
    } else if (e.key === 'Escape') {
      setOpen(false)
    }
  }

  return (
    <div className="ax-search">
      <label className="cx-search">
        {busy ? <Loader2 size={18} className="ax-spin" color="#94a3b8" /> : isCode(q.trim()) ? <Barcode size={18} color="#e11d2e" /> : <Search size={18} color="#94a3b8" />}
        <input
          ref={input}
          value={q}
          autoFocus={autoFocus}
          onChange={(e) => setQ(e.target.value)}
          onKeyDown={onKeyDown}
          onFocus={() => items.length && setOpen(true)}
          onBlur={() => setTimeout(() => setOpen(false), 150)}
          placeholder={placeholder || 'Scanner un code-barres ou chercher un article…'}
          inputMode="search"
          autoComplete="off"
        />
        <kbd className="ax-kbd">Entrée</kbd>
      </label>
      {open && items.length ? (
        <div className="ax-suggest" role="listbox">
          {items.map((a, i) => (
            <button
              key={a.id}
              type="button"
              role="option"
              aria-selected={i === active}
              className={`ax-suggest-item ${i === active ? 'on' : ''}`}
              onMouseEnter={() => setActive(i)}
              onMouseDown={(e) => {
                e.preventDefault()
                pick(a)
              }}
            >
              {a.image ? <img src={a.image} alt="" /> : <span className="ax-thumb" />}
              <span className="ax-suggest-main">
                <b>{a.name_fr || a.nom}</b>
                <small>
                  {a.marque?.nom ? `${a.marque.nom} · ` : ''}
                  {a.code_article}
                </small>
              </span>
              <span className="ax-suggest-side">
                {Number(a.prix?.prix_vente || 0) > 0 ? `${Number(a.prix.prix_vente).toFixed(2)} DH` : 'À tarifer'}
                <small>Stock {Number(a.stock?.quantite || 0)}</small>
              </span>
            </button>
          ))}
        </div>
      ) : null}
    </div>
  )
})

export default ArticleSearch
