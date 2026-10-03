import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  LabelList,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { 
  ChevronLeft, 
  ChevronRight, 
  ShoppingBag, 
  DollarSign, 
  TrendingUp, 
  Award, 
  Clock,
  ArrowRight,
  Download,
  FileText
} from 'lucide-react'
import { apiFetch, getToken } from '../../lib/api'
import Alert from '../../components/Alert'
import '../../styles/dashboard.css'

export default function Dashboard() {
  const [range, setRange] = useState('week')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const [selectedDate, setSelectedDate] = useState(() => {
    const now = new Date()
    const y = now.getFullYear()
    const m = String(now.getMonth() + 1).padStart(2, '0')
    const d = String(now.getDate()).padStart(2, '0')
    return `${y}-${m}-${d}`
  })

  const [month, setMonth] = useState(() => selectedDate.slice(0, 7))

  const [metrics, setMetrics] = useState({ orders_count: 0, revenue: 0 })
  const [period, setPeriod] = useState({ start: '', end: '' })
  const [chart, setChart] = useState({ points: [], best_day: '—', best_value: 0 })
  const [summary, setSummary] = useState([])
  const [calendarDays, setCalendarDays] = useState([])

  const rangeLabel = useMemo(() => {
    switch (range) {
      case 'today':
        return "Aujourd'hui"
      case 'yesterday':
        return 'Hier'
      case 'month':
        return 'Ce mois'
      case 'week':
      default:
        return 'Cette semaine'
    }
  }, [range])

  const chartData = useMemo(() => (Array.isArray(chart?.points) ? chart.points : []), [chart])

  const bestDay = useMemo(() => (chart?.best_day ? String(chart.best_day) : '—'), [chart])

  const bestValue = useMemo(() => Number(chart?.best_value ?? 0), [chart])

  const yMax = useMemo(() => {
    const max = chartData.reduce((acc, it) => (Number(it.value) > acc ? Number(it.value) : acc), 0)
    const padded = Math.ceil(max * 1.15)
    return padded <= 0 ? 0 : padded
  }, [chartData])

  const bestLabel = useMemo(() => {
    const v = Number(bestValue) || 0
    if (range === 'month') return `${v.toLocaleString('fr-FR')} cmd`
    return `${v} cmd`
  }, [bestValue, range])

  const monthTitle = useMemo(() => {
    const [y, m] = month.split('-').map((x) => Number(x))
    if (!y || !m) return ''
    const dt = new Date(y, m - 1, 1)
    const title = new Intl.DateTimeFormat('fr-FR', { month: 'long', year: 'numeric' }).format(dt)
    return title.slice(0, 1).toUpperCase() + title.slice(1)
  }, [month])

  const calendarMap = useMemo(() => {
    const map = new Map()
    for (const d of calendarDays || []) {
      if (d?.date) map.set(String(d.date), d)
    }
    return map
  }, [calendarDays])

  const calendarCells = useMemo(() => {
    const [y, m] = month.split('-').map((x) => Number(x))
    if (!y || !m) return []

    const first = new Date(y, m - 1, 1)
    const firstDow = (first.getDay() + 6) % 7
    const gridStart = new Date(y, m - 1, 1 - firstDow)

    const cells = []
    for (let i = 0; i < 42; i += 1) {
      const d = new Date(gridStart)
      d.setDate(gridStart.getDate() + i)
      const yy = d.getFullYear()
      const mm = String(d.getMonth() + 1).padStart(2, '0')
      const dd = String(d.getDate()).padStart(2, '0')
      const key = `${yy}-${mm}-${dd}`
      cells.push({
        key,
        day: d.getDate(),
        inMonth: d.getMonth() === first.getMonth(),
        dateObj: d,
        hasData: Number(calendarMap.get(key)?.orders ?? 0) > 0,
      })
    }
    return cells
  }, [month, calendarMap])

  const selectedWeek = useMemo(() => {
    const [y, m, d] = selectedDate.split('-').map((x) => Number(x))
    if (!y || !m || !d) return null
    const dt = new Date(y, m - 1, d)
    const dow = (dt.getDay() + 6) % 7
    const start = new Date(dt)
    start.setDate(dt.getDate() - dow)
    const end = new Date(start)
    end.setDate(start.getDate() + 6)
    return { start, end }
  }, [selectedDate])

  const periodLabel = useMemo(() => {
    if (!period?.start || !period?.end) return rangeLabel
    const [sy, sm, sd] = period.start.split('-').map((x) => Number(x))
    const [ey, em, ed] = period.end.split('-').map((x) => Number(x))
    if (!sy || !sm || !sd || !ey || !em || !ed) return rangeLabel
    const s = new Date(sy, sm - 1, sd)
    const e = new Date(ey, em - 1, ed)
    const fmt = new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short' })
    const sTxt = fmt.format(s)
    const eTxt = fmt.format(e)
    return `${rangeLabel} • ${sTxt} → ${eTxt}`
  }, [period, rangeLabel])

  const revenueLabel = useMemo(() => {
    const v = Number(metrics?.revenue ?? 0)
    return `${v.toLocaleString('fr-FR', { maximumFractionDigits: 0 })} DH`
  }, [metrics])

  const revenueTrend = useMemo(() => {
    const pct = Number(metrics?.compare?.revenue_pct ?? 0)
    const sign = pct > 0 ? '+' : ''
    const label =
      range === 'week' ? 'vs semaine passée' : range === 'month' ? 'vs mois passé' : 'vs jour précédent'
    return `${sign}${pct.toLocaleString('fr-FR')}% ${label}`
  }, [metrics, range])

  const ordersLabel = useMemo(() => {
    const v = Number(metrics?.orders_count ?? 0)
    return v.toLocaleString('fr-FR')
  }, [metrics])

  useEffect(() => {
    let alive = true
    async function run() {
      setLoading(true)
      setError('')
      try {
        const qs = new URLSearchParams({
          range,
          date: selectedDate,
          month,
        }).toString()
        const res = await apiFetch(`/api/admin/dashboard/stats?${qs}`)
        if (!alive) return
        setMetrics(res?.metrics || { orders_count: 0, revenue: 0 })
        setPeriod(res?.period || { start: '', end: '' })
        setChart(res?.chart || { points: [], best_day: '—', best_value: 0 })
        setSummary(Array.isArray(res?.summary) ? res.summary : [])
        setCalendarDays(Array.isArray(res?.calendar?.days) ? res.calendar.days : [])
      } catch (e) {
        if (!alive) return
        setError(e?.message || 'Erreur')
      } finally {
        if (alive) setLoading(false)
      }
    }
    run()
    return () => {
      alive = false
    }
  }, [range, selectedDate, month])

  async function downloadReport() {
    try {
      const qs = new URLSearchParams({
        range,
        download: 'csv'
      }).toString();
      
      const token = getToken();
      // Ensure we use the correct base path
      const url = `/api/admin/reports/sales?${qs}`;
      
      const response = await fetch(url, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Accept': 'text/csv'
        }
      });
      
      if (!response.ok) throw new Error('Erreur lors du téléchargement');
      
      const blob = await response.blob();
      const downloadUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.setAttribute('download', `rapport_ventes_${range}.csv`);
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(downloadUrl);
    } catch (e) {
      setError(e.message);
    }
  }

  function renderBestLabel(props) {
    const { x, y, width, value, payload } = props || {}
    if (!payload || payload.day !== bestDay) return null

    const label = range === 'month' ? `${Number(value || 0).toLocaleString('fr-FR')} cmd` : `${value} cmd`
    const bx = Number(x || 0) + Number(width || 0) / 2
    const by = Number(y || 0) - 18
    const rectW = Math.max(54, label.length * 7.2)
    const rectH = 22
    const rx = 10

    return (
      <g>
        <rect
          x={bx - rectW / 2}
          y={by - rectH}
          width={rectW}
          height={rectH}
          rx={rx}
          ry={rx}
          fill="#0b1220"
          opacity="0.95"
        />
        <text
          x={bx}
          y={by - rectH / 2 + 4}
          textAnchor="middle"
          fill="#ffffff"
          fontSize="11"
          fontWeight="800"
        >
          {label}
        </text>
      </g>
    )
  }

  function ChartTooltip({ active, payload, label }) {
    if (!active || !payload?.length) return null
    const v = payload[0]?.value
    return (
      <div className="dash-tooltip">
        <div className="dash-tooltip-title">{label}</div>
        <div className="dash-tooltip-row">
          <div className="dash-tooltip-key">Commandes</div>
          <div className="dash-tooltip-val">{`${v} cmd`}</div>
        </div>
      </div>
    )
  }

  function prevMonth() {
    const [y, m] = month.split('-').map((x) => Number(x))
    if (!y || !m) return
    const dt = new Date(y, m - 2, 1)
    const yy = dt.getFullYear()
    const mm = String(dt.getMonth() + 1).padStart(2, '0')
    setMonth(`${yy}-${mm}`)
  }

  function nextMonth() {
    const [y, m] = month.split('-').map((x) => Number(x))
    if (!y || !m) return
    const dt = new Date(y, m, 1)
    const yy = dt.getFullYear()
    const mm = String(dt.getMonth() + 1).padStart(2, '0')
    setMonth(`${yy}-${mm}`)
  }

  function isSameDay(a, b) {
    return a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
  }

  function isBetween(d, start, end) {
    const t = d.getTime()
    return t >= start.getTime() && t <= end.getTime()
  }

  function onPickDay(cell) {
    const d = cell?.dateObj
    if (!d) return
    const yy = d.getFullYear()
    const mm = String(d.getMonth() + 1).padStart(2, '0')
    const dd = String(d.getDate()).padStart(2, '0')
    const ymd = `${yy}-${mm}-${dd}`
    setSelectedDate(ymd)
    const ym = `${yy}-${mm}`
    if (ym !== month) setMonth(ym)
  }

  const calSelected = useMemo(() => {
    const [y, m, d] = selectedDate.split('-').map((x) => Number(x))
    if (!y || !m || !d) return null
    return new Date(y, m - 1, d)
  }, [selectedDate])

  return (
    <section className="content dash">
      <div className="dash-head">
        <div>
          <div className="dash-title">Tableau de bord</div>
          <div className="dash-subtitle">
            <span className="dash-subtitle-dot" />
            Données: <b>{rangeLabel}</b>
          </div>
        </div>



        <div className="dash-ranges" role="tablist" aria-label="Période">
          <button
            className={range === 'today' ? 'dash-range dash-range-active' : 'dash-range'}
            type="button"
            onClick={() => setRange('today')}
          >
            Aujourd&apos;hui
          </button>
          <button
            className={range === 'yesterday' ? 'dash-range dash-range-active' : 'dash-range'}
            type="button"
            onClick={() => setRange('yesterday')}
          >
            Hier
          </button>
          <button
            className={range === 'week' ? 'dash-range dash-range-active' : 'dash-range'}
            type="button"
            onClick={() => setRange('week')}
          >
            Cette semaine
          </button>
          <button
            className={range === 'month' ? 'dash-range dash-range-active' : 'dash-range'}
            type="button"
            onClick={() => setRange('month')}
          >
            Ce mois
          </button>
        </div>
      </div>

      <Alert type="error" message={error} />

      <div className="dash-grid">
        <div className="dash-col">
          <div className="dash-card">
            <div className="dash-card-head">
              <div className="dash-card-title">{monthTitle}</div>
              <div className="dash-card-nav">
                <button className="dash-ico" type="button" aria-label="Précédent" onClick={prevMonth}>
                  <ChevronLeft size={16} />
                </button>
                <button className="dash-ico" type="button" aria-label="Suivant" onClick={nextMonth}>
                  <ChevronRight size={16} />
                </button>
              </div>
            </div>
            <div className="dash-calendar">
              <div className="dash-cal-head">
                {['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'].map((d) => (
                  <div key={d} className="dash-cal-dow">
                    {d}
                  </div>
                ))}
              </div>
              <div className="dash-cal-grid">
                {calendarCells.map((cell) => {
                  const muted = !cell.inMonth
                  const active = calSelected ? isSameDay(cell.dateObj, calSelected) : false
                  const inWeek =
                    range === 'week' && selectedWeek ? isBetween(cell.dateObj, selectedWeek.start, selectedWeek.end) : false
                  const cls = [
                    'dash-cal-day',
                    muted ? 'dash-cal-day-muted' : '',
                    inWeek ? 'dash-cal-day-pill' : '',
                    active ? 'dash-cal-day-active' : '',
                    cell.hasData ? 'dash-cal-day-has' : '',
                  ]
                    .filter(Boolean)
                    .join(' ')
                  return (
                    <button key={cell.key} className={cls} type="button" onClick={() => onPickDay(cell)}>
                      {cell.day}
                    </button>
                  )
                })}
              </div>
            </div>
          </div>

          <div className="dash-metric dash-metric-red">
            <div className="dash-metric-head">
              <div className="dash-metric-title">Commandes</div>
              <div className="dash-metric-badge">
                <ShoppingBag size={16} color="white" />
              </div>
            </div>
            <div className="dash-metric-value">{loading ? '—' : ordersLabel}</div>
            <div className="dash-metric-sub">{periodLabel}</div>
          </div>

          <div className="dash-metric dash-metric-blue">
            <div className="dash-metric-head">
              <div className="dash-metric-title">Chiffre d&apos;affaires</div>
              <div className="dash-metric-badge">
                <DollarSign size={16} color="#3b82f6" />
              </div>
            </div>
            <div className="dash-metric-value dark">{loading ? '—' : revenueLabel}</div>
            <div className="dash-metric-trend">
              <span className="dash-trend-pill">
                <TrendingUp size={14} style={{ marginRight: '4px' }} />
                {loading ? '—' : revenueTrend}
              </span>
            </div>
            <div className="dash-metric-note">Données calculées à partir des ventes.</div>
          </div>
        </div>

        <div className="dash-col dash-col-wide">
          <div className="dash-card dash-card-chart">
            <div className="dash-card-head">
              <div>
                <div className="dash-card-title">Performance</div>
                <div className="dash-card-sub">Volume de commandes</div>
              </div>
              <div className="dash-chip-row">
                <button className="dash-chip" type="button">
                  Meilleur jour: <b>{bestDay}</b> <span className="dash-chip-sep" />{' '}
                  <span className="dash-chip-val">{bestLabel}</span>
                </button>
                <button className="dash-chip dash-chip-active" type="button">
                  Commandes
                </button>
              </div>
            </div>

            <div className="dash-chart">
              <ResponsiveContainer width="100%" height={280}>
                <BarChart
                  data={chartData}
                  margin={{ top: 26, right: 18, left: 0, bottom: 6 }}
                  barCategoryGap={18}
                  barGap={6}
                >
                  <CartesianGrid stroke="#eef2f7" vertical={false} />
                  <XAxis dataKey="day" tickLine={false} axisLine={false} stroke="#94a3b8" fontSize={12} />
                  <YAxis tickLine={false} axisLine={false} stroke="#94a3b8" fontSize={11} domain={[0, yMax]} />
                  <Tooltip
                    cursor={{ fill: 'rgba(2,6,23,0.03)' }}
                    content={<ChartTooltip />}
                  />
                  <Bar dataKey="value" radius={[8, 8, 8, 8]} maxBarSize={46}>
                    {chartData.map((entry) => (
                      <Cell
                        key={`cell-${entry.day}`}
                        fill={entry.day === bestDay ? '#3b82f6' : 'rgba(59, 130, 246, 0.15)'}
                      />
                    ))}
                    <LabelList dataKey="value" content={renderBestLabel} />
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>

          <div className="dash-card">
            <div className="dash-card-head dash-card-head-split">
              <div>
                <div className="dash-card-title">Résumé des périodes</div>
                <div className="dash-card-sub">Synthèse des périodes les plus actives</div>
              </div>
              <Link className="dash-link" to="/admin/ventes">
                Voir détail <ArrowRight size={14} style={{ marginLeft: '4px', verticalAlign: 'middle' }} />
              </Link>
            </div>

            <div className="dash-table-wrap">
              <table className="dash-table">
                <thead>
                  <tr>
                    <th>Période</th>
                    <th>Commandes</th>
                    <th>Chiffre d'affaires</th>
                    <th>Statut</th>
                  </tr>
                </thead>
                <tbody>
                  {(summary || []).map((row, idx) => {
                    const label = row?.label ? String(row.label) : '—'
                    const orders = Number(row?.orders ?? 0)
                    const revenue = Number(row?.revenue ?? 0)
                    const amount = `${revenue.toLocaleString('fr-FR', { maximumFractionDigits: 0 })} DH`
                    const tag = row?.tag ? String(row.tag) : ''
                    const tagCls =
                      tag.includes('Peak') ? 'dash-tag dash-tag-green' : tag === 'Plus bas' ? 'dash-tag dash-tag-amber' : 'dash-tag'
                    
                    const Icon = idx === 0 ? Award : idx === 1 ? TrendingUp : Clock
                    const iconColor = idx === 0 ? '#f59e0b' : idx === 1 ? '#10b981' : '#3b82f6'

                    return (
                      <tr key={`${label}-${idx}`}>
                        <td>
                          <div className="dash-table-cell-main">
                            <div className="dash-table-icon" style={{ backgroundColor: `${iconColor}15`, color: iconColor }}>
                              <Icon size={14} />
                            </div>
                            <span>{label}</span>
                          </div>
                        </td>
                        <td><span className="dash-table-val">{orders.toLocaleString('fr-FR')} cmd</span></td>
                        <td><span className="dash-table-amount">{amount}</span></td>
                        <td><span className={tagCls}>{tag || 'Normal'}</span></td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
