import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { ArrowRight, ChevronRight, ImagePlus, PackageOpen, Pencil, Trash2, X } from 'lucide-react'
import '../../styles/catalogue.css'


export function Hero({ crumbs = [], title, titleAr, subtitle, image, stats = [], actions }) {
  return (
    <header className="cx-hero">
      <div className="cx-hero-row">
        <div style={{ display: 'flex', gap: 18, alignItems: 'center', minWidth: 0 }}>
          {image ? <img className="cx-hero-thumb" src={image} alt="" /> : null}
          <div style={{ minWidth: 0 }}>
            {crumbs.length ? (
              <nav className="cx-crumbs" aria-label="Fil d’Ariane">
                {crumbs.map((c, i) => (
                  <span key={i} style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                    {c.to ? <Link to={c.to}>{c.label}</Link> : <span>{c.label}</span>}
                    {i < crumbs.length - 1 ? <ChevronRight size={14} /> : null}
                  </span>
                ))}
              </nav>
            ) : null}
            <h1 className="cx-title">{title}</h1>
            {titleAr ? <div className="cx-title-ar">{titleAr}</div> : null}
            {subtitle ? <div className="cx-sub">{subtitle}</div> : null}
          </div>
        </div>
        {actions ? <div className="cx-hero-actions">{actions}</div> : null}
      </div>
      {stats.length ? (
        <div className="cx-stats">
          {stats.map((s) => (
            <div key={s.label} className={`cx-stat ${s.warn ? 'cx-stat-warn' : ''}`}>
              <div className="cx-stat-value">{s.value}</div>
              <div className="cx-stat-label">{s.label}</div>
            </div>
          ))}
        </div>
      ) : null}
    </header>
  )
}

export function EntityCard({ image, title, titleAr, pills = [], onOpen, onEdit, onDelete }) {
  return (
    <article
      className="cx-card"
      role="button"
      tabIndex={0}
      onClick={onOpen}
      onKeyDown={(e) => (e.key === 'Enter' ? onOpen?.() : null)}
    >
      <div className="cx-card-media">
        {image ? <img src={image} alt="" loading="lazy" /> : <div className="cx-card-fallback">{(title || '?')[0]}</div>}
        {(onEdit || onDelete) && (
          <div className="cx-card-tools" onClick={(e) => e.stopPropagation()}>
            {onEdit ? (
              <button className="cx-icon-btn" type="button" title="Modifier" onClick={onEdit}>
                <Pencil size={16} />
              </button>
            ) : null}
            {onDelete ? (
              <button className="cx-icon-btn cx-icon-btn-danger" type="button" title="Supprimer" onClick={onDelete}>
                <Trash2 size={16} />
              </button>
            ) : null}
          </div>
        )}
      </div>
      <div className="cx-card-body">
        <div className="cx-card-title">{title}</div>
        {titleAr ? <div className="cx-card-ar">{titleAr}</div> : null}
        <div className="cx-card-meta">
          {pills.map((p) => (
            <span key={p.label} className={`cx-pill ${p.tone ? `cx-pill-${p.tone}` : ''}`}>
              {p.label}
            </span>
          ))}
        </div>
      </div>
      <span className="cx-card-go" aria-hidden>
        <ArrowRight size={16} />
      </span>
    </article>
  )
}

export function Skeletons({ count = 8, height }) {
  return Array.from({ length: count }, (_, i) => <div key={i} className="cx-skel" style={height ? { minHeight: height } : null} />)
}

export function Empty({ title, children, action }) {
  return (
    <div className="cx-empty">
      <PackageOpen size={38} color="#94a3b8" />
      <div className="cx-empty-title">{title}</div>
      <div>{children}</div>
      {action ? <div style={{ marginTop: 14 }}>{action}</div> : null}
    </div>
  )
}

/**
 * Fenêtre de création / modification : nom FR, nom AR, parent facultatif, image (glisser-déposer).
 * onSubmit({ name_fr, name_ar, parent_id, file })
 */
export function EntityModal({ open, title, initial, parentLabel, parents, parentKey, requireImage, onClose, onSubmit }) {
  const [nameFr, setNameFr] = useState('')
  const [nameAr, setNameAr] = useState('')
  const [parentId, setParentId] = useState('')
  const [file, setFile] = useState(null)
  const [preview, setPreview] = useState(null)
  const [over, setOver] = useState(false)
  const [busy, setBusy] = useState(false)
  const inputRef = useRef(null)

  useEffect(() => {
    if (!open) return
    setNameFr(initial?.name_fr ?? '')
    setNameAr(initial?.name_ar ?? '')
    setParentId(initial?.parent_id != null ? String(initial.parent_id) : '')
    setFile(null)
    setPreview(initial?.image ?? null)
    setBusy(false)
    // Réinitialiser seulement à l'ouverture : `initial` est souvent un objet recréé à chaque rendu.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open])

  useEffect(() => {
    if (!file) return undefined
    const url = URL.createObjectURL(file)
    setPreview(url)
    return () => URL.revokeObjectURL(url)
  }, [file])

  useEffect(() => {
    if (!open) return undefined
    const onKey = (e) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onClose])

  if (!open) return null

  const missingImage = requireImage && !file && !initial?.image
  const valid = (nameFr.trim() || nameAr.trim()) && (!parents || parentId) && !missingImage

  async function submit(e) {
    e.preventDefault()
    if (!valid || busy) return
    setBusy(true)
    try {
      await onSubmit({ name_fr: nameFr.trim(), name_ar: nameAr.trim(), parent_id: parentId || null, file })
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="cx-modal-back" onMouseDown={onClose}>
      <div className="cx-modal" role="dialog" aria-modal="true" onMouseDown={(e) => e.stopPropagation()}>
        <div className="cx-modal-head">
          <div className="cx-modal-title">{title}</div>
          <button className="cx-icon-btn" type="button" onClick={onClose} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>
        <form className="cx-modal-body" onSubmit={submit}>
          {parents ? (
            <label className="cx-field">
              {parentLabel}
              <select value={parentId} onChange={(e) => setParentId(e.target.value)} required>
                <option value="">Choisir…</option>
                {parents.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p[parentKey] || p.nom || p.nom_fr}
                  </option>
                ))}
              </select>
            </label>
          ) : null}
          <div className="cx-two">
            <label className="cx-field">
              Nom en français
              <input value={nameFr} onChange={(e) => setNameFr(e.target.value)} placeholder="Ex. Boissons" autoFocus />
            </label>
            <label className="cx-field cx-field-ar">
              الاسم بالعربية
              <input value={nameAr} onChange={(e) => setNameAr(e.target.value)} placeholder="مثال: المشروبات" />
            </label>
          </div>
          <div
            className={`cx-drop ${over ? 'over' : ''}`}
            onClick={() => inputRef.current?.click()}
            onDragOver={(e) => {
              e.preventDefault()
              setOver(true)
            }}
            onDragLeave={() => setOver(false)}
            onDrop={(e) => {
              e.preventDefault()
              setOver(false)
              const f = e.dataTransfer.files?.[0]
              if (f && f.type.startsWith('image/')) setFile(f)
            }}
          >
            {preview ? <img src={preview} alt="" /> : <div className="cx-drop-empty"><ImagePlus size={26} /></div>}
            <div className="cx-drop-text">
              <b>{preview ? 'Changer l’image' : 'Ajouter une image'}</b>
              <br />
              Glissez une photo ici ou cliquez (JPG, PNG, WebP).
              {missingImage ? <div style={{ color: '#dc2626', marginTop: 4 }}>Image obligatoire.</div> : null}
            </div>
            <input ref={inputRef} type="file" accept="image/*" hidden onChange={(e) => setFile(e.target.files?.[0] || null)} />
          </div>
          <div className="cx-modal-foot">
            <button className="cx-btn" type="button" onClick={onClose}>
              Annuler
            </button>
            <button className="cx-btn cx-btn-primary" type="submit" disabled={!valid || busy}>
              {busy ? 'Enregistrement…' : 'Enregistrer'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
