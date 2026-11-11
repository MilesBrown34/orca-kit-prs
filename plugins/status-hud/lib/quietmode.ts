import type { QuietErr } from '../types'
import type { Config } from './config'
import { type Io, sh } from './io'

/** null = not configured (the chip is hidden). */
export async function quietModeOn(io: Io, c: Config, exists: (p: string) => Promise<boolean>): Promise<boolean | null> {
  if (c.quietFlagFile !== '') return exists(c.quietFlagFile)
  if (c.quietStatusCmd !== '') return (await io.run(sh(c.quietStatusCmd), 10_000)).exitCode === 0
  return null
}

export function canToggle(c: Config): boolean {
  return c.quietOnCmd !== '' && c.quietOffCmd !== ''
}

/**
 * The installed orchestration kit's folder, from Claude Code's installed_plugins.json: the quiet chip runs the kit's own
 * scripts/quiet-mode.sh from there, so it works in every session (the switch is one flag file for the whole machine).
 * '' when the kit is not installed or the file cannot be read. A kit installed from a folder is run from that folder
 * instead (`kitFolderFrom`); this is the installed copy every other install runs from.
 */
export function kitDirFrom(installedPluginsJson: string | null): string {
  try {
    const plugins = (JSON.parse(installedPluginsJson ?? '') as { plugins?: Record<string, { installPath?: unknown }[]> }).plugins ?? {}
    const key = Object.keys(plugins).find(k => k.startsWith('orchestration-kit@'))
    const p = key ? plugins[key]?.[0]?.installPath : undefined
    return typeof p === 'string' ? p : ''
  } catch {
    return ''
  }
}

/**
 * The kit's own folder when it was installed from a folder on this machine (a `directory` marketplace in Claude Code's
 * known_marketplaces.json): Claude Code reads such an install in place, so the installed copy can be older than the kit
 * the sessions run. '' for any other install. The caller confirms the folder is the kit with `isKitManifest`.
 */
export function kitFolderFrom(installedPluginsJson: string | null, knownMarketplacesJson: string | null): string {
  try {
    const plugins = (JSON.parse(installedPluginsJson ?? '') as { plugins?: Record<string, unknown> }).plugins ?? {}
    const key = Object.keys(plugins).find(k => k.startsWith('orchestration-kit@'))
    if (!key) return ''
    const markets = JSON.parse(knownMarketplacesJson ?? '') as Record<string, { source?: { source?: unknown }; installLocation?: unknown }>
    const m = markets[key.slice('orchestration-kit@'.length)]
    return m?.source?.source === 'directory' && typeof m.installLocation === 'string' ? m.installLocation.replace(/\/$/, '') : ''
  } catch {
    return ''
  }
}

/** Whether a folder's .claude-plugin/plugin.json is the orchestration kit's (the folder itself is the plugin). */
export function isKitManifest(pluginJson: string | null): boolean {
  try {
    return (JSON.parse(pluginJson ?? '') as { name?: unknown }).name === 'orchestration-kit'
  } catch {
    return false
  }
}

/** How long a failed press stays on the chip. */
export const QUIET_ERR_MS = 60_000

/**
 * Whether the chip can work in this session: the on/off commands run in `dir` (the kit's folder, else the session's),
 * so their script has to be there. No check for an empty requires-file (custom commands) or a status-only chip (nothing to press).
 */
export async function quietAvailable(c: Config, dir: string, exists: (p: string) => Promise<boolean>): Promise<boolean> {
  if (!canToggle(c) || c.quietRequiresFile === '') return true
  return exists(c.quietRequiresFile.startsWith('/') ? c.quietRequiresFile : `${dir.replace(/\/$/, '')}/${c.quietRequiresFile}`)
}

export type ToggleResult = { ran: boolean; wanted: boolean; ok: boolean; detail?: string }

/** Runs the configured on/off command (from `dir`, else home) for the OPPOSITE of the current state; returns the state asked for. */
export async function toggleQuietMode(io: Io, c: Config, current: boolean | null, dir = ''): Promise<ToggleResult> {
  const wanted = current !== true
  if (!canToggle(c)) return { ran: false, wanted, ok: false }
  const r = await io.run(sh(wanted ? c.quietOnCmd : c.quietOffCmd), 30_000, dir || undefined)
  if (r.exitCode === 0) return { ran: true, wanted, ok: true }
  // A missing script or a shell error speaks on stderr; stdout wins when both have something.
  const firstLine = (t: string): string | undefined => t.split('\n').map(l => l.trim()).find(l => l !== '')
  const first = firstLine(r.stdout) ?? firstLine(r.stderr ?? '')
  return { ran: true, wanted, ok: false, detail: `exit ${r.exitCode}${first ? `: ${first}` : ''}` }
}

/** What the chip does, in plain words (the pane caption prints all of it, wrapped; /hud help starts with it). */
export const QUIET_EXPLAIN = 'QUIET holds NEW test/gate runs while you use the machine; running ones finish. WORK lets them start normally. Click the chip to switch.'

/** The toast after a good press. */
export const quietNote = (on: boolean): string =>
  on ? 'Quiet ON: new test/gate runs wait; running ones finish. Press again to turn it off.' : 'Quiet OFF: new test/gate runs start normally.'

/** A failed press as the chip state (the toast shows the same message). */
export const quietFailure = (r: ToggleResult, now: number): QuietErr => ({
  wanted: r.wanted,
  msg: r.ran ? (r.detail ?? 'failed') : 'quietModeOnCmd/quietModeOffCmd are not set',
  until: now + QUIET_ERR_MS,
})
