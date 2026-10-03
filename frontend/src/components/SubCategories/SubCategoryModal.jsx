import { useState } from 'react'
import { X } from 'lucide-react'

export function SubCategoryModal({ open, onClose, onSubmit }) {
  const [nameAr, setNameAr] = useState('')
  const [nameFr, setNameFr] = useState('')
  const [file, setFile] = useState(null)

  if (!open) return null

  function submit(e) {
    e.preventDefault()
    if (!(nameAr.trim() || nameFr.trim())) return
    if (!file) return
    onSubmit({ 
      name_ar: nameAr.trim(),
      name_fr: nameFr.trim(),
      file 
    })
    setNameAr('')
    setNameFr('')
    setFile(null)
  }

  return (
    <div className="modal-overlay" onMouseDown={onClose}>
      <div className="modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-title">Ajouter une Catégorie</div>
          <button className="modal-x" type="button" onClick={onClose} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>
        <form className="modal-body" onSubmit={submit}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <label className="form-label">
              Nom (Français)
              <input className="form-input" value={nameFr} onChange={(e) => setNameFr(e.target.value)} placeholder="Ex: Pates" />
            </label>
          <label className="form-label">
              Nom (Arabe)
              <input className="form-input" value={nameAr} onChange={(e) => setNameAr(e.target.value)}  placeholder=" مثال :عجين" dir="rtl" />
            </label>
          </div>
          <label className="form-label">
            Image
            <input className="form-input" type="file" accept="image/*" onChange={(e) => setFile(e.target.files?.[0] || null)} />
          </label>
          <div className="modal-foot">
            <button className="btn-ghost" type="button" onClick={onClose}>
              Annuler
            </button>
            <button className="btn-primary" type="submit" disabled={!(nameAr.trim() || nameFr.trim()) || !file}>
              Ajouter
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
