// The setup page's data: the band drawn for a sample in which every item shows, and where each item sits.
// Each item is found by drawing the band again with only that item hidden: the first cell that changes is
// where its number goes, so the page follows the real layout code and never a hand-drawn picture.
// Usage (from the kit): bash scripts/hud-guide.sh build   — writes docs/status-hud-guide.html
import { parseConfig } from '../lib/config'
import { drawBand, type Line } from '../lib/layout'
import type { Heartbeat, Snapshot } from '../types'

export const COLS = 180

/** Every item, in the README's order, with a plain name, what it shows (`what`) and when you see it (`seen`).
 * `when` = a short tag for items drawn only sometimes; `shows` = how they come to be drawn: 'auto' by itself when
 * `when` applies, 'setting' only after the user turns something on (`turnOn` says how); absent = shown by default. */
export const ITEMS: { id: string; area: string; name: string; what: string; seen: string; when?: string; shows?: 'auto' | 'setting'; turnOn?: string }[] = [
  { id: 'host-title', area: 'Machine', name: 'Machine title', what: 'The heading of the machine box: how many processor threads this computer has.',
    seen: 'All the time, at the top left of the HUD.' },
  { id: 'cpu', area: 'Machine', name: 'CPU meter', what: 'How busy the processor is: the 1-minute load against the number of threads.',
    seen: 'All the time. It turns red when the load nears the thread count (90% of it unless the cpuRedLoad setting says otherwise), which usually means several sessions are running tests or builds at once.' },
  { id: 'history', area: 'Machine', name: 'History graphs', what: 'The small graphs to the right of the CPU, memory and graphics meters: the last few minutes of each reading.',
    seen: 'All the time, as long as the terminal window is wide enough to fit them beside the meters.' },
  { id: 'ram', area: 'Machine', name: 'Memory (RAM)', what: 'Memory in use out of the total, as the machine running the sessions sees it.',
    seen: 'All the time.' },
  { id: 'win', area: 'Machine', name: 'Windows memory limit', what: 'How much of the memory Windows can promise is promised. At 100% Windows stops WSL, and every session with it, with nothing logged inside Linux.',
    seen: 'Only on Windows with WSL; never on a Mac or plain Linux. Read every 30 seconds. It turns amber at 85% and red at 95% (commitWarnPct, commitCritPct), and an alert chip appears too.', when: 'WSL only', shows: 'auto' },
  { id: 'gpu', area: 'Machine', name: 'Graphics card', what: 'How busy the graphics card is, and its temperature.',
    seen: 'Only on a machine with an NVIDIA card (the HUD asks nvidia-smi). It climbs while a session runs image, 3D or AI-model work on the card.', when: 'with an NVIDIA card', shows: 'auto' },
  { id: 'vram', area: 'Machine', name: 'Graphics memory', what: 'Memory on the graphics card in use out of the total.',
    seen: 'Only on a machine with an NVIDIA card. When the box is short of rows it is the first meter dropped, after extra disks.', when: 'with an NVIDIA card', shows: 'auto' },
  { id: 'disk', area: 'Machine', name: 'Main disk', what: 'Space used on the first drive in the mounts setting (the main drive, / , unless you change it). Amber from 80% full, red from 90%.',
    seen: 'All the time.' },
  { id: 'disk2', area: 'Machine', name: 'Other disks', what: 'Space used on each further drive you list in the mounts setting.',
    seen: 'Only after you add a drive, and only when the box has a free row for it.', when: 'add a drive to the mounts setting', shows: 'setting',
    turnOn: 'Add the drive to the mounts setting, e.g. mounts: /,/mnt/data (ask Claude to do it).' },
  { id: 'sessions-title', area: 'Sessions', name: 'Sessions title', what: 'The heading of the sessions box: how many Claude sessions are running, and across how many accounts or projects.',
    seen: 'All the time.' },
  { id: 'context-key', area: 'Sessions', name: 'Context colour key', what: 'Explains the bar colours: green is fine, amber is filling up (300K tokens by default), red is past the point where a session should report and hand over (350K).',
    seen: 'All the time, on the row under the title.' },
  { id: 'dot-key', area: 'Sessions', name: 'Project key', what: 'Which dot colour is which project, by name.',
    seen: 'Only with project dots, beside the colour key when there is room.', when: 'choose project dots above', shows: 'setting',
    turnOn: 'Pick "Its project (tab colour)" at the top of this page.' },
  { id: 'state-key', area: 'Sessions', name: 'Busy/idle key', what: 'Explains the mark after each session: ▘ busy (it turns while working), $ running a command, ○ idle.',
    seen: 'All the time, at the end of the key row under the title.' },
  { id: 'dot', area: 'Sessions', name: 'Session dot', what: 'A coloured dot at the start of each session row: its Claude account, or its project (the colour of its terminal tab when the launcher recorded one). The choice is at the top of this page.',
    seen: 'All the time, on every session row.' },
  { id: 'model', area: 'Sessions', name: 'Model badge', what: 'Which model the session runs: OPS (Opus, yellow), SNT (Sonnet, blue), HKU (Haiku, green), GEM (Gemini, purple).',
    seen: 'All the time, on every session row, right after its name.' },
  { id: 'bar', area: 'Sessions', name: 'Context bar', what: 'How full the session\'s context (its working memory) is, coloured by the key. A session that crosses the report mark flashes red for a few seconds.',
    seen: 'All the time, on every session row. It fills as the session works and empties when it is recycled.' },
  { id: 'tokens', area: 'Sessions', name: 'Context number', what: 'The same fill as a number of tokens, e.g. 230K. A ~ after it means amber, a ! means red.',
    seen: 'All the time, on every session row.' },
  { id: 'state', area: 'Sessions', name: 'Busy/idle mark', what: 'Whether the session is working (▘, turning), running a command ($), or waiting for you (○).',
    seen: 'All the time, on every session row; it changes as the session works.' },
  { id: 'activity', area: 'Sessions', name: 'Last action', what: 'What the session did last: the tool\'s own short description or name. Never your prompt text, a raw command, a file path or a web address.',
    seen: 'All the time, on every session row, once the session has done something.' },
  { id: 'column2', area: 'Sessions', name: 'Second column', what: 'A second column of session rows, so more sessions fit.',
    seen: 'Only when more than five sessions run at once and the window is wide; otherwise the extra ones are summed up as "+N more".', when: 'more than five sessions', shows: 'auto' },
  { id: 'frame-title', area: 'Sessions', name: 'STATUS HUD label', what: 'The name on the top-right corner of the frame.',
    seen: 'All the time.' },
  { id: 'work-mode', area: 'Bottom chips', name: 'Work/Quiet mode', what: 'A button: Quiet holds new test runs (started through the kit\'s gate throttle) so the machine stays responsive while you use it; runs already going finish. Work is normal. Click it to switch.',
    seen: 'Only in a project the kit set up (it has scripts/quiet-mode.sh), or while quiet mode is on.', when: 'in projects set up by the kit', shows: 'auto' },
  { id: 'count', area: 'Bottom chips', name: 'Session count', what: 'How many sessions are reporting.',
    seen: 'All the time.' },
  { id: 'live', area: 'Bottom chips', name: 'Live version', what: 'The version of this project that is live now, as the board records it when a release ships (its DEPLOY line, e.g. "DEPLOY FREE (live v1.4.2)").',
    seen: 'Only once the project has shipped a release with its version written on the board.', when: 'after a recorded release', shows: 'auto' },
  { id: 'apps', area: 'Bottom chips', name: 'Programs in use', what: 'One chip per program a session drives while it runs: Blender, Godot, Gemini by default (the trackApps setting), and on Windows any program a session starts, under its own name; each names the sessions that started it; +N counts copies no session started, such as one you opened yourself. A ComfyUI chip shows its jobs running and waiting.',
    seen: 'Only while one of those programs is running, or ComfyUI has jobs.', when: 'while a tracked program runs', shows: 'auto' },
  { id: 'warnings', area: 'Bottom chips', name: 'Alerts', what: 'Red or amber chips at the right, most urgent first: Windows memory near its limit, sessions past the report mark (named), a CPU load in the red.',
    seen: 'Only when something needs you; when all is fine there are none. This picture shows two so you can see them.', when: 'when something needs you', shows: 'auto' },
]

const S = (name: string, k: number, state: Heartbeat['state'], project: string, color: string, account: number, activity: string): Heartbeat =>
  ({ id: name, name, model: 'opus', account, tokens: k * 1000, window: 1_000_000, state, activity, at: 0, project, color })
const sessions = [
  S('Lead', 170, 'busy', 'my-app', '#16a085', 1, 'orchestrating · row 7 gate queued'),
  { ...S('Mars', 64, 'busy', 'my-app', '#16a085', 1, 'row 6-3 settings page'), apps: ['blender'] },
  S('Venus', 362, 'busy', 'my-app', '#16a085', 2, 'row 7-7 final gate'),
  S('Vulcan', 231, 'shell', 'my-app', '#16a085', 2, 'npm test'),
  S('Apollo', 120, 'idle', 'my-app', '#16a085', 1, 'READ row 6-4'),
  S('Lotus', 95, 'busy', 'website', '#8e44ad', 1, 'editing index.html'),
  S('Finch', 40, 'idle', 'website', '#8e44ad', 2, 'Bash'),
]
const wave = (n: number, a: number, b: number, p: number): number[] => Array.from({ length: n }, (_, i) => a + b * Math.sin(i / p))
export const SNAP: Snapshot = {
  now: 0, selfId: 'Lead', sessions, quietMode: false, live: 'v1.4.2',
  host: {
    at: 0, threads: 20, load: [18.6, 17.9, 16.2], ramUsedGb: 9.8, ramTotalGb: 16,
    gpu: { util: 31, vramUsedGb: 3.1, vramTotalGb: 8, tempC: 52 },
    disks: [{ mount: '/', usedGb: 410, totalGb: 1007 }, { mount: '/data', usedGb: 1200, totalGb: 2000 }],
    commit: { usedPct: 88, limitGb: 40, usedGb: 35, at: 0 },
    apps: { blender: 1 },
    hist: { load: wave(60, 15, 4, 5), ram: wave(60, 9, 1, 7), gpu: wave(60, 30, 15, 3) },
  },
}

type Cell = [string, string, string, number] // char, fg, bg ('' = none), bold
const grid = (lines: Line[]): Cell[][] =>
  lines.map(l => l.flatMap(sg => sg.runs.flatMap(r => Array.from(r.text).map((ch): Cell => [ch, r.fg, r.bg ?? '', r.bold ? 1 : 0]))))
const draw = (opts: Record<string, string>): Cell[][] =>
  grid(drawBand({ snap: SNAP, cfg: parseConfig({ quietModeOnCmd: 'a', quietModeOffCmd: 'b', ...opts }, '/h'), flash: {}, sel: -1, now: 0 }, COLS, 10))
const same = (a: Cell | undefined, b: Cell | undefined): boolean => !!a && !!b && a.join('\u0000') === b.join('\u0000')

/** Where an item sits: per row it touches, the columns that are its own (the rest of the row only shifted). */
function locate(full: Cell[][], hidden: Cell[][]): { row: number; from: number; to: number }[] {
  const out: { row: number; from: number; to: number }[] = []
  for (let y = 0; y < full.length; y++) {
    const a = full[y] ?? [], b = hidden[y] ?? []
    let x = 0
    while (x < a.length && same(a[x], b[x])) x++
    if (x >= a.length) continue
    // The item's cells: the shortest span after which this row and the hidden row line up again.
    let to = a.length
    for (let k = 1; k <= 60 && x + k < a.length; k++) {
      let ok = true
      for (let j = 0; j < 8 && x + k + j < a.length; j++) if (!same(a[x + k + j], b[x + j])) { ok = false; break }
      if (ok) { to = x + k; break }
    }
    if (to === a.length) { to = x; while (to < a.length && !same(a[to], b[to])) to++ }
    out.push({ row: y, from: x, to })
  }
  return out
}

const METERS = ['cpu', 'ram', 'win', 'gpu', 'vram', 'disk', 'disk2']

type At = { row: number; from: number; to: number }[]

/** Where each item sits in the picture for one dot choice: an item that choice does not draw (the project key with account dots) has no place. */
function place(dotMode: 'account' | 'project'): Map<string, At> {
  const full = draw({ dotMode })
  const out = new Map<string, At>()
  for (const it of ITEMS) {
    // The project key goes with the dots, so the dots are found with the key already off; the second column
    // also changes the title's count, so its place is below the title.
    const base = it.id === 'dot' ? draw({ dotMode, hideItems: 'dot-key' }) : full
    let at = locate(base, draw({ dotMode, hideItems: it.id === 'dot' ? 'dot,dot-key' : it.id }))
    if (it.id === 'column2') at = at.filter(a => a.row > 0)
    // Rows below a removed meter move up, and a removed chip moves the rest: keep the rows that are the
    // item's own. Per-session items touch every session row; anything else is one row.
    const perRow = ['dot', 'bar', 'tokens', 'state', 'activity'].includes(it.id)
    if (!perRow) at = at.slice(0, 1)
    else at = at.filter(a => a.row >= 2 && a.row <= 6)
    // A meter owns its whole row in the machine box: label, bar and reading (the rows below only move up, so the
    // compare above finds just the label). The history graphs start at column 34.
    if (METERS.includes(it.id) && at[0]) {
      const row = full[at[0].row] ?? []
      // up to the history graphs when this row has one, else up to the box's divider
      const divider = row.findIndex((c, x) => x > 2 && c[0] === '│')
      let to = (row[34]?.[0] ?? ' ') !== ' ' ? 33 : (divider > 0 ? divider : row.length)
      while (to > 2 && (row[to - 1]?.[0] ?? ' ') === ' ') to--
      at = [{ row: at[0].row, from: 2, to }]
    }
    // A span never crosses a box divider: past it is the next box (a compare that found no realignment runs on).
    at = at.map(a => {
      const row = full[a.row] ?? []
      let to = a.to
      for (let x = a.from + 1; x < a.to; x++) if (row[x]?.[0] === '│') { to = x; break }
      if (to < a.to) while (to > a.from + 1 && (row[to - 1]?.[0] ?? ' ') === ' ') to--
      return { ...a, to }
    })
    out.set(it.id, at)
  }
  return out
}

/** `at` is the item's place with project dots, `atAccount` with account dots: the page uses the one for the picture it shows. */
export function guideData(): { cols: number; account: Cell[][]; project: Cell[][]; items: (typeof ITEMS[number] & { at: At; atAccount: At })[] } {
  const project = place('project')
  const account = place('account')
  return {
    cols: COLS,
    account: draw({ dotMode: 'account' }),
    project: draw({ dotMode: 'project' }),
    items: ITEMS.map(it => ({ ...it, at: project.get(it.id) ?? [], atAccount: account.get(it.id) ?? [] })),
  }
}

if (process.argv[1]?.endsWith('guide.ts')) process.stdout.write(JSON.stringify(guideData()))
