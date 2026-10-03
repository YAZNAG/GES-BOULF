export function PromoTabs({ tab, setTab }) {
  return (
    <div className="promo-tabs">
      <button
        className={tab === 'all' ? 'promo-tab promo-tab-active' : 'promo-tab'}
        type="button"
        onClick={() => setTab('all')}
      >
        Toutes
      </button>
      <button
        className={tab === 'active' ? 'promo-tab promo-tab-active' : 'promo-tab'}
        type="button"
        onClick={() => setTab('active')}
      >
        Actives
      </button>
      <button
        className={tab === 'inactive' ? 'promo-tab promo-tab-active' : 'promo-tab'}
        type="button"
        onClick={() => setTab('inactive')}
      >
        Inactives
      </button>
    </div>
  )
}
