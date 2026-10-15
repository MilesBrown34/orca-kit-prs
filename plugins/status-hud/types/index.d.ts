export type Busy = 'busy' | 'idle' | 'shell'

/** One session's self-report, written to <statusDir>/sessions/<id>.json. */
export type Heartbeat = {
  id: string
  name: string
  model: string
  /** 1 or 2: from CLAUDE_CONFIG_DIR (none = 1). */
  account: number
  tokens: number
  window: number
  state: Busy
  activity: string
  at: number
  /** The kit project the session works in (its main checkout's folder name); absent outside a repo. */
  project?: string
  /** The session's dot color in project mode (#rrggbb): its tab's recorded color, else its project's; '' = none. */
  color?: string
  /** Tracked programs (trackApps) running under this session, one label per instance. */
  apps?: string[]
}

/** The shared host reading, written to <statusDir>/host.json by whichever session finds it stale. */
export type Host = {
  at: number
  threads: number
  load: [number, number, number]
  ramUsedGb: number
  ramTotalGb: number
  disks: { mount: string; usedGb: number; totalGb: number }[]
  gpu: { util: number; vramUsedGb: number; vramTotalGb: number; tempC: number } | null
  commit: { usedPct: number; limitGb: number; usedGb: number; at: number } | null
  /** Tracked programs running anywhere on the machine (Linux and, on WSL, Windows), by label. */
  apps?: Record<string, number>
  /** Windows' tracked-program counts and when they were read (the Windows call is slow, so it is spaced out). */
  winApps?: { n: Record<string, number>; at: number } | null
  /** ComfyUI's queue (comfyUrl); null when it does not answer. */
  queue?: { running: number; pending: number } | null
  hist: { load: number[]; ram: number[]; gpu: number[] }
}

export type Snapshot = {
  now: number
  selfId: string
  sessions: Heartbeat[]
  host: Host | null
  /** null = no quiet mode configured. */
  quietMode: boolean | null
  /** False = the toggle's script is missing where this session runs, so the chip is hidden (undefined counts as available). */
  quietAvail?: boolean
  /** The last failed press, shown as a red chip until `until` (epoch ms). */
  quietErr?: QuietErr | null
  /** The live version of this session's project, from its board ('' = none recorded). */
  live?: string
}

export type QuietErr = { wanted: boolean; msg: string; until: number }

declare module 'claude-code' {
  interface PluginState {
    'status-hud': {
      snap: Snapshot | null
      /** session id -> epoch ms until which it flashes red. */
      flash: Record<string, number>
      /** Highlighted session index in the pane. */
      sel: number
      /** Runtime variant override from /hud (config is the default). */
      variant: string | null
    }
  }
}
