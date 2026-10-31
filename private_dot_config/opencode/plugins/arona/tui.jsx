// ARONA for OpenCode v2 (TUI plugin): in-flight requests in the prompt's status row, a toast when one
// appears or changes status, /arona lists them.
// wikk installs this next to arona.ts, the Claude Code mod's shared logic (agentskill/arona/hooks/arona.ts).
// OpenCode compiles a plugin's .jsx with Solid (@opentui/solid) as it loads it, so this needs no build step.
import { execFile } from 'node:child_process'
import { createSignal, Show } from 'solid-js'
import { action, dots, isShown, label, statusKey, toReqs, transition } from './arona.ts'

const run = (cli) =>
  new Promise((resolve) =>
    execFile(cli, ['resource', 'list', '--limit', '20', '--json'], { timeout: 20_000 }, (err, stdout, stderr) =>
      resolve({ missing: err?.code === 'ENOENT', code: err ? (typeof err.code === 'number' ? err.code : 1) : 0, stdout, stderr }),
    ),
  )

// wikk is the CLI's name; installs older than the rename only have wikiwiki.
async function list() {
  let last = 'wikk not installed'
  for (const cli of ['wikk', 'wikiwiki']) {
    const ran = await run(cli)
    if (ran.missing) continue
    const parsed = ran.code === 0 ? toReqs(ran.stdout) : null
    if (parsed) return { reqs: parsed }
    last = (ran.stderr || ran.stdout).trim().slice(0, 200) || `${cli} exited ${ran.code}`
  }
  return { error: last }
}

function summary(reqs) {
  const now = Date.now()
  const first = reqs.find((r) => action(r)) ?? reqs[0]
  return `◉ ARONA ${first.id.slice(0, 8)} ${label(first, now)}${reqs.length > 1 ? ` 외 ${reqs.length - 1}건` : ''}`
}

const line = (r, now) => `${r.id.slice(0, 8)} ${dots(r.status)} ${label(r, now)}${r.failure ? ` · ${r.failure}` : ''}${action(r) ? ` → ${action(r)}` : ''}`

export default {
  id: 'arona',
  async setup(ctx) {
    let busy = false
    let disposed = false
    let error = ''
    let seen = null
    const changed = {}
    // What the status row shows: in-flight requests and ones that just ended.
    const [rows, setRows] = createSignal([])
    const toast = (message, variant = 'info') => ctx.ui.toast.show({ title: 'ARONA', message, variant })

    async function refresh() {
      if (busy) return null
      busy = true
      try {
        const got = await list()
        // A poll that finishes after the plugin was disposed must not toast.
        if (disposed) return null
        if ('error' in got) {
          if (!error) toast(`조회 실패: ${got.error} (로그인: wikk auth login)`, 'warning')
          error = got.error
          setRows([])
          return got
        }
        if (error) toast('조회 복구됨', 'success')
        error = ''
        const now = Date.now()
        const next = {}
        for (const r of got.reqs) {
          next[r.id] = statusKey(r)
          // The first poll is a silent baseline, else every old request would toast as new.
          const news = seen && transition(seen[r.id], r, now)
          if (news) {
            toast(news.replace(/^ARONA /, ''), r.failure ? 'error' : action(r) ? 'warning' : 'info')
            changed[r.id] = now
          }
        }
        seen = next
        setRows(got.reqs.filter((r) => isShown(r, now, changed[r.id])))
        return got
      } finally {
        busy = false
      }
    }

    // One line: the most urgent request (a human action first), then how many more.
    ctx.ui.slot({
      append: 'prompt.footer.status',
      render: () => (
        <Show when={rows().length > 0}>
          <box flexShrink={0}>
            <text>{summary(rows())}</text>
          </box>
        </Show>
      ),
    })

    ctx.keymap.layer(() => ({
      mode: 'global',
      commands: [
        {
          id: 'arona.list',
          title: 'ARONA requests',
          group: 'System',
          slash: { name: 'arona' },
          palette: true,
          async run() {
            const got = (await refresh()) ?? (await list())
            if ('error' in got) return toast(got.error, 'error')
            const now = Date.now()
            toast(got.reqs.length ? got.reqs.slice(0, 10).map((r) => line(r, now)).join('\n') : '요청이 없습니다.')
          },
        },
      ],
    }))

    const poll = () => void refresh().catch(() => {})
    const timer = setInterval(poll, 30_000)
    timer.unref?.()
    poll()
    return () => {
      disposed = true
      clearInterval(timer)
    }
  },
}
