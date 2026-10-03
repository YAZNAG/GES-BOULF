const subs = new Set()
let toastSeq = 1

export function toast(input) {
  const opts = typeof input === 'string' ? { message: input } : input || {}
  const message = (opts.message || '').toString()
  if (!message) return null

  const item = {
    id: String(toastSeq++),
    type: opts.type === 'success' ? 'success' : 'error',
    message,
    timeout: Number.isFinite(Number(opts.timeout)) ? Number(opts.timeout) : 3200,
  }

  for (const fn of subs) fn({ type: 'add', item })
  return item.id
}

export function subscribe(fn) {
  if (typeof fn !== 'function') return () => {}
  subs.add(fn)
  return () => subs.delete(fn)
}

