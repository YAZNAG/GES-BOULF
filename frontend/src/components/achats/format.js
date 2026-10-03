export const money = (n) =>
  new Intl.NumberFormat('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(Number(n || 0))

export const qty = (n) => new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 3 }).format(Number(n || 0))

export const dateFr = (d) => (d ? new Date(`${String(d).slice(0, 10)}T00:00:00`).toLocaleDateString('fr-FR') : '—')

export const today = () => new Date().toISOString().slice(0, 10)

export const STATUTS_BC = {
  brouillon: 'Brouillon',
  confirmee: 'Confirmé',
  partielle: 'Reçu en partie',
  recue: 'Reçu',
  annulee: 'Annulé',
}

export const MODES_PAIEMENT = [
  { value: 'especes', label: 'Espèces' },
  { value: 'cheque', label: 'Chèque' },
  { value: 'virement', label: 'Virement' },
  { value: 'effet', label: 'Effet / traite' },
  { value: 'carte', label: 'Carte' },
]

export const modeLabel = (v) => MODES_PAIEMENT.find((m) => m.value === v)?.label || v || '—'

export const json = (method, data) => ({
  method,
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(data),
})

export const articleName = (a) => a?.name_fr || a?.nom || '—'
