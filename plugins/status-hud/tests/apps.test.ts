import { expect, test } from 'claude-code/testing'

import { countApps, countWindows, liveVersion, matchArgs, parseApps, parsePs, parseQueue, windowsProgram } from '../lib/apps'
import { parseConfig } from '../lib/config'
import { refreshHost } from '../lib/hostRefresh'
import { chips, type View } from '../lib/layout'
import type { Snapshot } from '../types'
import { SAMPLE_OUT, fakeIo } from './fakeio'

const APPS = parseApps('blender, godot,gemini=gemini ,blender')

test('trackApps: labels in order, lower case, duplicates dropped, label=name kept', async () => {
  expect(APPS).toEqual([{ label: 'blender', pat: 'blender' }, { label: 'godot', pat: 'godot' }, { label: 'gemini', pat: 'gemini' }])
  expect(parseApps('')).toEqual([])
  expect(parseApps('paint=krita')).toEqual([{ label: 'paint', pat: 'krita' }])
})

test('a process matches by its program file or the script a runtime runs; Windows paths and .exe too', async () => {
  expect(matchArgs('/mnt/c/Program Files/Blender Foundation/Blender 4.2/blender.exe -b x.blend', APPS)).toBe('blender')
  expect(matchArgs('/mnt/c/Blender/blender.exe -b x.blend --python rig.py', APPS)).toBe('blender')
  expect(matchArgs('godot --headless --path /tmp/g', APPS)).toBe('godot')
  expect(matchArgs('Godot_v4.7-stable_win64.exe', APPS)).toBe('godot')
  expect(matchArgs('node /usr/local/bin/gemini --yolo', APPS)).toBe('gemini')
  expect(matchArgs('node --max-old-space-size=4096 server.js', APPS)).toBe(null)
  expect(matchArgs('timeout 120 godot --import', APPS)).toBe(null) // the wrapper is not the program; its child is
})

const PS = [
  '  100     1 claude --name Mars',
  '  110   100 /bin/bash -c timeout 120 godot --headless',
  '  111   110 timeout 120 godot --headless',
  '  112   111 godot --headless --path /tmp/g',
  '  113   112 godot --headless --path /tmp/g', // the program's own helper: same instance
  '  200     1 claude --name Venus',
  '  210   200 /mnt/c/Blender/blender.exe -b a.blend',
  '  300     1 /usr/bin/godot --editor',          // opened by hand: no session's
  'garbage line',
].join('\n')

test('countApps: one label per instance, only under the given session, helpers not counted twice', async () => {
  const ps = parsePs(PS)
  expect(ps.length).toBe(8)
  expect(countApps(ps, APPS, 100)).toEqual(['godot'])
  expect(countApps(ps, APPS, 200)).toEqual(['blender'])
  expect(countApps(ps, APPS, 999)).toEqual([])
  expect(countApps(ps, APPS).sort()).toEqual(['blender', 'godot', 'godot'])
})

test('countWindows reads tasklist CSV image names', async () => {
  const out = '"System","4","Services","0","1,234 K"\r\n"blender.exe","9","Console","1","900,000 K"\r\n"Blender.exe","10","Console","1","1 K"\r\n"Discord.exe","11","Console","1","1 K"'
  expect(countWindows(out, APPS)).toEqual({ blender: 2 })
})

test('parseQueue: running and waiting jobs; anything else is null', async () => {
  expect(parseQueue('{"queue_running":[[1]],"queue_pending":[[2],[3]]}')).toEqual({ running: 1, pending: 2 })
  expect(parseQueue('')).toBe(null)
  expect(parseQueue('{"error":"x"}')).toBe(null)
})

test('liveVersion: from the DEPLOY slot line only; a bare number gets its v', async () => {
  expect(liveVersion('# Board\n**Slots:** DEPLOY FREE (live v1.4.2) · LOG FREE (next 3)\n')).toBe('v1.4.2')
  expect(liveVersion('**Slots:** DEPLOY FREE (live 0.3) · LOG FREE')).toBe('v0.3')
  expect(liveVersion('**Slots:** DEPLOY FREE · LOG FREE (next 1)')).toBe('')
  expect(liveVersion('we went live v9 yesterday\n**Slots:** DEPLOY FREE')).toBe('')
  expect(liveVersion('**Slots:** DEPLOY FREE · LOG FREE\n✅ LIVE v2.0.1 (main `abc`) · DEPLOY FREE · LOG FREE, next 4')).toBe('v2.0.1')
  expect(liveVersion('**Slots:** DEPLOY FREE (live v2.1.0)\n✅ LIVE v2.0.1 (main `abc`) · DEPLOY FREE')).toBe('v2.1.0')
})

test('host refresh: machine-wide counts take the larger of the Linux and Windows sides; queue read; Windows spaced out', async () => {
  const c = parseConfig({ commitCmd: '', trackApps: 'blender,godot' }, '/h')
  let winCalls = 0
  const f = fakeIo({
    now: 10_000_000,
    runs: a => {
      const cmd = String(a[2] ?? '')
      if (cmd.includes('tasklist')) return (winCalls++, { exitCode: 0, stdout: '"blender.exe","1"\n"blender.exe","2"' })
      if (cmd.includes('/proc/loadavg')) {
        expect(cmd).toContain("C=/mnt/c/Windows/System32/curl.exe; [ -x \"$C\" ] || C=curl; \"$C\" -s -m 1 'http://127.0.0.1:8188/queue'")
        return { exitCode: 0, stdout: `${SAMPLE_OUT}\n##ps\n${PS}\n##queue\n{"queue_running":[],"queue_pending":[[1]]}` }
      }
      return undefined
    },
  })
  const r = await refreshHost(f.io, c)
  expect(r.host?.apps).toEqual({ godot: 2, blender: 2 })
  expect(r.host?.queue).toEqual({ running: 0, pending: 1 })
  f.setNow(10_006_000)
  await refreshHost(f.io, c)
  expect(winCalls).toBe(1)
  f.setNow(10_031_000)
  await refreshHost(f.io, c)
  expect(winCalls).toBe(2)
})

test('no tracked programs: no process list, no Windows call; no ComfyUI address: no curl', async () => {
  const c = parseConfig({ commitCmd: '', trackApps: '', comfyUrl: '' }, '/h')
  const f = fakeIo({ now: 10_000_000, runs: a => (a[0] === 'sh' ? { exitCode: 0, stdout: SAMPLE_OUT } : undefined) })
  const r = await refreshHost(f.io, c)
  const all = f.calls.map(a => a.join(' ')).join('\n')
  expect(all).not.toContain('ps -eo')
  expect(all).not.toContain('tasklist')
  expect(all).not.toContain('curl')
  expect(r.host?.queue).toBe(null)
})

const host: NonNullable<Snapshot['host']> = {
  at: 0, threads: 8, load: [1, 1, 1], ramUsedGb: 1, ramTotalGb: 8, disks: [], gpu: null, commit: null,
  apps: { blender: 3, godot: 1 }, queue: { running: 1, pending: 3 }, hist: { load: [], ram: [], gpu: [] },
}
const hb = (name: string, apps: string[]) => ({ id: name, name, model: 'opus', account: 1, tokens: 0, window: 1_000_000, state: 'idle' as const, activity: '', at: 0, apps })
const view = (o: Partial<Snapshot> = {}, opts: Record<string, string> = {}): View => ({
  snap: { now: 0, selfId: 'Mars', sessions: [hb('Mars', ['blender']), hb('Venus', ['blender'])], host, quietMode: null, live: 'v0.2', ...o },
  cfg: parseConfig(opts, '/h'), flash: {}, sel: 0, now: 0,
})
const labels = (v: View) => chips(v).map(c => c.label.trim())

test('chips: live version, each running program with its sessions and unclaimed copies, the ComfyUI queue', async () => {
  expect(labels(view())).toEqual(['2 sessions', 'live v0.2', 'blender ×3: Mars Venus +1', 'godot: running', 'comfyui 1 running · 3 queued'])
})

test('chips: nothing running, no queue, no version: none of them; hideItems switches them off', async () => {
  const idle = view({ live: '', sessions: [hb('Mars', [])], host: { ...host, apps: {}, queue: { running: 0, pending: 0 } } })
  expect(labels(idle)).toEqual(['1 sessions'])
  expect(labels(view({}, { hideItems: 'live,apps' }))).toEqual(['2 sessions'])
})

test('chips: a session count above the machine count still shows every session', async () => {
  expect(labels(view({ host: { ...host, apps: {} } }))).toContain('blender ×2: Mars Venus')
})

test('windowsProgram: the .exe a command runs (after wrappers only), named by its leading letters', async () => {
  expect(windowsProgram('/mnt/c/Program Files/Krita (x64)/bin/krita.exe --nosplash a.kra')).toBe('krita')
  expect(windowsProgram('timeout 1800 /mnt/f/3D Objects/Tools/Blender/blender.exe -b x.blend')).toBe('blender')
  expect(windowsProgram('/init /mnt/f/Godot/Godot_v4.7-stable_win64.exe --headless')).toBe('godot')
  expect(windowsProgram('Audacity.exe')).toBe('audacity')
  expect(windowsProgram('python3 tool.py --out build.exe')).toBe('') // an argument naming an .exe is not a program run
  expect(windowsProgram('sh -c P=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe; "$P" -Command x')).toBe('')
  expect(windowsProgram('godot --headless')).toBe('')
})

test('auto: a Windows program a session runs gets its own chip label; the ignore list and other sessions\' do not', async () => {
  const ps = parsePs([
    '  100     1 claude --name Mars',
    '  110   100 /mnt/c/Program Files/Krita/bin/krita.exe a.kra',
    '  111   110 /init /mnt/c/Program Files/Krita/bin/krita.exe a.kra',
    '  120   100 /mnt/c/Windows/System32/curl.exe -s x',
    '  130   100 /mnt/c/Blender/blender.exe -b',
    '  200     1 /mnt/c/Tools/obs64.exe',
  ].join('\n'))
  const ignore = new Set(['curl'])
  expect(countApps(ps, APPS, 100, ignore).sort()).toEqual(['blender', 'krita'])
  expect(countApps(ps, APPS, 100)).toEqual(['blender']) // auto off: listed programs only
  expect(countApps(ps, APPS, 0, ignore)).toEqual(['blender']) // never machine-wide: those would include ones opened by hand
})

test('chips: programs found by themselves follow the listed ones, by name', async () => {
  const v = view({ sessions: [hb('Mars', ['krita', 'blender']), hb('Venus', ['audacity'])], host: { ...host, apps: {}, queue: null } })
  expect(labels(v)).toEqual(['2 sessions', 'live v0.2', 'blender: Mars', 'audacity: Venus', 'krita: Mars'])
})

test('config: autoWindowsApps false switches finding off; ignoreApps replaces the default list', async () => {
  expect(parseConfig({ autoWindowsApps: false }, '/h').autoApps).toBe(null)
  expect([...(parseConfig({ ignoreApps: 'Foo, bar' }, '/h').autoApps ?? [])]).toEqual(['foo', 'bar'])
  expect(parseConfig({}, '/h').autoApps?.has('powershell')).toBe(true)
})
