import { useCallback, useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { ClipboardList, Pencil, Printer, Wallet } from 'lucide-react'
import { apiFetch } from '../../../lib/api'
import { toast } from '../../../lib/toast'
import { Hero } from '../../../components/catalogue/CatalogueUI'
import FournisseurForm from '../../../components/achats/FournisseurForm'
import PaiementFournisseurModal from '../../../components/achats/PaiementFournisseurModal'
import { STATUTS_BC, dateFr, modeLabel, money } from '../../../components/achats/format'
import '../../../styles/catalogue.css'
import '../../../styles/achats.css'

const TABS = [
  ['releve', 'Relevé de compte'],
  ['receptions', 'Réceptions'],
  ['paiements', 'Règlements'],
  ['commandes', 'Bons de commande'],
]

/** Fiche fournisseur : crédit, relevé, réceptions, règlements et bons de commande. */
export default function FournisseurFiche() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [f, setF] = useState(null)
  const [tab, setTab] = useState('releve')
  const [data, setData] = useState({})
  const [edit, setEdit] = useState(false)
  const [payer, setPayer] = useState(false)

  const load = useCallback(async () => {
    try {
      const [fiche, releve, receptions, paiements, commandes] = await Promise.all([
        apiFetch(`/api/fournisseurs/${id}`),
        apiFetch(`/api/achats/fournisseurs/${id}/releve`),
        apiFetch(`/api/achats/receptions?fournisseur_id=${id}&per_page=100`),
        apiFetch(`/api/achats/paiements?fournisseur_id=${id}&per_page=100`),
        apiFetch(`/api/achats/commandes?fournisseur_id=${id}&per_page=100`),
      ])
      setF(fiche)
      setData({ releve: releve.lignes, receptions: receptions.data, paiements: paiements.data, commandes: commandes.data })
    } catch (e) {
      toast({ type: 'error', message: e.message })
    }
  }, [id])

  useEffect(() => {
    const t = setTimeout(load, 0)
    return () => clearTimeout(t)
  }, [load])

  if (!f) return <section className="cx">Chargement…</section>
  const solde = Number(f.solde || 0)
  const depasse = f.plafond_credit && solde > Number(f.plafond_credit)

  return (
    <section className="cx">
      <Hero
        crumbs={[{ label: 'Achats' }, { label: 'Fournisseurs', to: '/admin/fournisseurs' }, { label: f.nom }]}
        title={f.nom}
        titleAr={f.contact ? `Contact : ${f.contact}` : null}
        subtitle={[f.telephone, f.email, f.ville, f.ice && `ICE ${f.ice}`, f.rc && `RC ${f.rc}`].filter(Boolean).join(' · ') || 'Aucune coordonnée'}
        stats={[
          { label: 'Crédit dû (DH)', value: money(solde), warn: solde > 0 },
          { label: 'Plafond (DH)', value: f.plafond_credit ? money(f.plafond_credit) : 'Illimité', warn: depasse },
          { label: 'Achats cumulés (DH)', value: money(f.total_achats) },
          { label: 'Payé cumulé (DH)', value: money(f.total_paye) },
          { label: 'Délai de paiement', value: f.delai_paiement ? `${f.delai_paiement} j` : '—' },
        ]}
        actions={
          <div className="ax-noprint" style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <button className="cx-btn cx-btn-ghost-light" type="button" onClick={() => setEdit(true)}>
              <Pencil size={16} /> Modifier
            </button>
            <button className="cx-btn cx-btn-ghost-light" type="button" onClick={() => window.print()}>
              <Printer size={16} /> Imprimer le relevé
            </button>
            <button className="cx-btn cx-btn-ghost-light" type="button" onClick={() => navigate('/admin/achats/commandes/nouveau')}>
              <ClipboardList size={16} /> Commander
            </button>
            <button className="cx-btn cx-btn-primary" type="button" disabled={solde <= 0} onClick={() => setPayer(true)}>
              <Wallet size={16} /> Régler
            </button>
          </div>
        }
      />

      <div className="cx-chips ax-noprint" style={{ marginTop: 16 }}>
        {TABS.map(([k, label]) => (
          <button key={k} className={`cx-chip ${tab === k ? 'on' : ''}`} type="button" onClick={() => setTab(k)}>
            {label}
            <span className="cx-chip-count">{data[k]?.length ?? 0}</span>
          </button>
        ))}
      </div>

      <div className="ax-table-wrap">
        {tab === 'releve' ? (
          <table className="ax-table">
            <thead>
              <tr>
                <th>Date</th>
                <th>Opération</th>
                <th className="ax-num">Achat (dû)</th>
                <th className="ax-num">Règlement</th>
                <th className="ax-num">Solde (DH)</th>
              </tr>
            </thead>
            <tbody>
              {!data.releve?.length ? (
                <tr className="ax-empty-row">
                  <td colSpan={5}>Aucune opération.</td>
                </tr>
              ) : null}
              {data.releve?.map((l, i) => (
                <tr key={i} className={l.type === 'reception' ? 'ax-click' : ''} onClick={() => l.type === 'reception' && navigate(`/admin/achats/receptions/${l.id}`)}>
                  <td>{dateFr(l.date)}</td>
                  <td>{l.libelle}</td>
                  <td className="ax-num ax-debit">{l.debit ? money(l.debit) : ''}</td>
                  <td className="ax-num ax-credit">{l.credit ? money(l.credit) : ''}</td>
                  <td className="ax-num ax-strong">{money(l.solde)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : null}

        {tab === 'receptions' ? (
          <table className="ax-table">
            <thead>
              <tr>
                <th>N°</th>
                <th>Date</th>
                <th>BL fournisseur</th>
                <th className="ax-num">Total</th>
                <th className="ax-num">Payé</th>
                <th>État</th>
              </tr>
            </thead>
            <tbody>
              {data.receptions?.map((r) => (
                <tr key={r.id} className="ax-click" onClick={() => navigate(`/admin/achats/receptions/${r.id}`)}>
                  <td className="ax-strong">{r.numero}</td>
                  <td>{dateFr(r.date_reception)}</td>
                  <td>{r.reference_fournisseur || '—'}</td>
                  <td className="ax-num">{money(r.total)}</td>
                  <td className="ax-num">{money(r.montant_paye)}</td>
                  <td>{r.reste > 0 ? <span className="ax-badge ax-st-du">Reste {money(r.reste)}</span> : <span className="ax-badge ax-st-paye">Soldée</span>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : null}

        {tab === 'paiements' ? (
          <table className="ax-table">
            <thead>
              <tr>
                <th>Date</th>
                <th>Mode</th>
                <th>Référence</th>
                <th>Réception</th>
                <th>Note</th>
                <th className="ax-num">Montant (DH)</th>
              </tr>
            </thead>
            <tbody>
              {data.paiements?.map((p) => (
                <tr key={p.id}>
                  <td>{dateFr(p.date_paiement)}</td>
                  <td>{modeLabel(p.mode)}</td>
                  <td>{p.reference || '—'}</td>
                  <td>{p.reception?.numero || '—'}</td>
                  <td className="ax-muted">{p.note}</td>
                  <td className="ax-num ax-strong ax-credit">{money(p.montant)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : null}

        {tab === 'commandes' ? (
          <table className="ax-table">
            <thead>
              <tr>
                <th>N°</th>
                <th>Date</th>
                <th className="ax-num">Total</th>
                <th>Statut</th>
              </tr>
            </thead>
            <tbody>
              {data.commandes?.map((c) => (
                <tr key={c.id} className="ax-click" onClick={() => navigate(`/admin/achats/commandes/${c.id}`)}>
                  <td className="ax-strong">{c.numero}</td>
                  <td>{dateFr(c.date_commande)}</td>
                  <td className="ax-num">{money(c.total)}</td>
                  <td>
                    <span className={`ax-badge ax-st-${c.statut}`}>{STATUTS_BC[c.statut]}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : null}
      </div>

      {edit ? (
        <FournisseurForm
          open
          fournisseur={f}
          onClose={() => setEdit(false)}
          onSaved={() => {
            setEdit(false)
            load()
          }}
        />
      ) : null}
      <PaiementFournisseurModal
        open={payer}
        fournisseur={f}
        onClose={() => setPayer(false)}
        onDone={() => {
          setPayer(false)
          load()
        }}
      />
    </section>
  )
}
