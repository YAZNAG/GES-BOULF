export default function Placeholder({ title, subtitle }) {
  return (
    <section className="content">
      <div className="page-head">
        <div>
          <div className="page-title">{title}</div>
          {subtitle ? <div className="page-subtitle">{subtitle}</div> : null}
        </div>
      </div>
      <div className="placeholder">
        <div className="placeholder-card">Bla API daba (fake page)</div>
      </div>
    </section>
  )
}

