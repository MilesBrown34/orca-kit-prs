// Tracked programs (trackApps) and the live version: pure parsing; register.tsx and hostRefresh.ts run the commands.

export type App = { label: string; pat: string }

/** `trackApps`: "blender,godot,gemini=gemini-cli": a label, optionally `=` the program name it matches (default the label). */
export function parseApps(spec: string): App[] {
  const out: App[] = []
  for (const part of spec.split(',')) {
    const [label = '', pat = ''] = part.split('=').map(s => s.trim().toLowerCase())
    if (label !== '' && !out.some(a => a.label === label)) out.push({ label, pat: pat || label })
  }
  return out
}

/** A program name for matching: the file name, lower case, without `.exe`. */
const base = (s: string): string => (s.split(/[\\/]/).pop() ?? '').toLowerCase().replace(/\.exe$/, '')

/**
 * The label a process's command line matches: its program, the script a runtime (node, python) was handed, or a
 * Windows program started from Linux (its path may hold spaces, e.g. Program Files, so the `.exe` name is found whole).
 */
export function matchArgs(args: string, apps: readonly App[]): string | null {
  const [a0 = '', a1 = ''] = args.trim().split(/\s+/)
  const exe = /^[^-][^\n]*?([^\\/]+)\.exe\b/i.exec(args.trim())?.[1] ?? ''
  const names = [base(a0), a1.startsWith('-') ? '' : base(a1), exe.toLowerCase()]
  return apps.find(a => names.some(n => n !== '' && n.startsWith(a.pat)))?.label ?? null
}

type Proc = { pid: number; ppid: number; args: string }

/** `ps -eo pid=,ppid=,args=` lines. */
export function parsePs(out: string): Proc[] {
  const ps: Proc[] = []
  for (const l of out.split('\n')) {
    const m = /^\s*(\d+)\s+(\d+)\s+(.*)$/.exec(l)
    if (m) ps.push({ pid: Number(m[1]), ppid: Number(m[2]), args: m[3] as string })
  }
  return ps
}

/**
 * One label per running instance. A process whose parent chain already matched the same label is part of that
 * instance (a program's own helpers), so it is not counted again. `root` limits it to that process's descendants
 * (a session's own runs); 0 counts the whole machine.
 */
export function countApps(ps: readonly Proc[], apps: readonly App[], root = 0): string[] {
  const byPid = new Map(ps.map(p => [p.pid, p]))
  const label = new Map(ps.map(p => [p.pid, matchArgs(p.args, apps)]))
  const out: string[] = []
  for (const p of ps) {
    const l = label.get(p.pid)
    if (!l) continue
    let under = root === 0
    let counted = false
    const seen = new Set<number>()
    for (let q = byPid.get(p.ppid); q && !seen.has(q.pid); q = byPid.get(q.ppid)) {
      seen.add(q.pid)
      if (label.get(q.pid) === l) counted = true
      if (q.pid === root) {
        under = true
        break
      }
    }
    if (under && !counted) out.push(l)
  }
  return out
}

/** `tasklist /fo csv /nh` rows: the first quoted field is the image name. */
export function countWindows(out: string, apps: readonly App[]): Record<string, number> {
  const n: Record<string, number> = {}
  for (const l of out.split('\n')) {
    const img = /^"([^"]+)"/.exec(l.trim())?.[1]
    const lab = img ? matchArgs(img, apps) : null
    if (lab) n[lab] = (n[lab] ?? 0) + 1
  }
  return n
}

/** ComfyUI's `/queue` answer: jobs running and waiting; null when it is not a queue answer. */
export function parseQueue(text: string): { running: number; pending: number } | null {
  try {
    const v = JSON.parse(text) as { queue_running?: unknown; queue_pending?: unknown }
    if (!Array.isArray(v.queue_running) || !Array.isArray(v.queue_pending)) return null
    return { running: v.queue_running.length, pending: v.queue_pending.length }
  } catch {
    return null
  }
}

/**
 * The live version from the board: the first line naming the DEPLOY slot and a live version, i.e. the slots line
 * as the seat releases it (`DEPLOY FREE (live v1.4.2)`), else a handover's `✅ LIVE v1.4.2 (main …) · DEPLOY FREE`.
 */
export function liveVersion(board: string): string {
  const line = board.split('\n').find(l => /\bDEPLOY\b/.test(l) && /\blive\s+v?\d/i.test(l)) ?? ''
  const v = /\blive\s+(v?\d[\w.+-]*)/i.exec(line)?.[1] ?? ''
  return v === '' ? '' : v.startsWith('v') ? v : `v${v}`
}
