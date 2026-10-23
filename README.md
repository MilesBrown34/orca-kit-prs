<!-- own-fork:top -->
**This is PRS's fork of Artekka's orchestration kit.** It is his kit, kept current with his releases, plus the
extras in the table below: things built while running it on real projects, kept as separate branches and offered
to him one at a time. Install this fork to get all of them. The official release is **v1.0.0**, on Artekka's 0.9.0;
releases are on the Releases page, and this fork's changelog is at the end of this file (20 extras).

| Extra | What it does |
|---|---|
| Start word | your start word opens a project menu (with the kit's version); starts a team, one chat, or sets the kit up; setup asks which word you want; `update_cmd=` adds [u] update the kit to the menu |
| Bypass | bypass shows up in Shift+Tab, while sessions still start in normal mode |
| Tabs | one Windows Terminal tab color per project; team names (w1-Mars, w2-Venus), your names asked once per machine |
| Status bar | the status bar's setup page, project dots, warnings on the right (most urgent first) |
| HUD setup Done | the status bar's setup page saves with one Done press, explains each number in a pop-up, jumps to it in the list, labels when each item appears, opens at kit-init, and is shown in the README |
| Programs and live version | status bar chips for each program a session drives while it runs (Blender, Godot, Gemini, and any Windows program a session starts, found by itself; who started it, +N for copies no session claims) and ComfyUI's queue (asked through Windows' curl); a `live v…` chip from the board's DEPLOY line, which the seat now writes as `DEPLOY FREE (live <version>)` |
| Kit update | `/orchestration-kit:kit-update` and `scripts/kit-update.sh`: shows when a newer kit exists, updates it (and the status bar) on a yes, warns open sessions keep the old version, lists projects whose copied scripts are older and refreshes them |
| Model badges | OPS (yellow), SNT (blue), HKU (green), GEM (purple) right after each session's name in the status bar |
| Session state | a busy session's mark turns clockwise (▘ ▝ ▗ ▖), and the status bar's key explains ▘ busy, $ shell, ○ idle |
| Background state | a session whose turn ended while background work it started still runs shows ◔ (cyan) instead of ○ idle, with `bg: <first job> +N` as its activity; it can be talked to but is not done |
| Programs on a background row | a ◔ row's activity ends with the tracked programs its background work is running (`bg: Run the checks · godot ×2`) |
| CPU temperature | the status bar's CPU line shows the load and the CPU temperature (`5.1 72°C`), read from Linux's own sensor or, on WSL, from LibreHardwareMonitor running on Windows; without a reading it keeps `5.1/16t` |
| Koi icon | the status bar pane's icon is a koi (white with red patches) instead of the horned helmet |
| Lessons from the checks | eighty new lessons (61–140) in docs/LESSONS.md, distilled from real checks and guards, and 22 existing lessons extended |
| Gate log | `gate-throttle.sh --log <file>`: once the slot is held, the gate's output goes to the file, opening with the commit (`SHA …`) and `started <time> dirty=<n>` read at that moment and ending with `exit <code>`, so a gate log names the code it tested |
| Gate memory | `gate-throttle.sh`: a normal slot beyond the first only while available memory (`MemAvailable`) is at least `GATE_MIN_FREE_MB` (default 3072); below that one normal slot at a time; unreadable = admit; `KIT_MEMINFO_FILE` fakes the reading in tests |
| Cap count fix | a team start no longer quits silently when no Claude is running (the session-cap count read pgrep's "found none" as an error) |
| Lighter seat skill | the seat skill's deploy, log and recycle/handover steps sit in two files beside it (`deploy-and-log.md`, `recycle-and-handover.md`), read only before those steps; every seat start loads ~850 tokens less |
| Skill checks | `tests/skills-lint.test.sh` refuses a skill or agent with a wrong name, a missing or over-long description, a cited file that does not exist, or a personal home path (`KIT_PRIVATE_WORDS=<file>` adds a private word list); `scripts/skill-usage.py <log folder>` shows which kit skills a project's sessions ran and which never |
| Fork README | the README's top block (this fork, its official version, the extras table) and the changelog at its end are this fork's own; the release command rewrites both on this branch and merges it, so never sent |
<!-- /own-fork:top -->

# orchestration-kit



Run **several Claude Code sessions on one repo at the same time** without file collisions,
lost work, or confabulated green: a shared claimable board, one git worktree per session,
and every piece of work verified by a session that didn't build it. Proven on the origin
project: three concurrent sessions, ~15 workstreams, one evening, zero collisions.

## Quickstart — a seat and two siblings (5 minutes)

```bash
# 1. Install into your repo (normal shell, not inside Claude; on Windows run `wsl` first)
cd ~/projects/myapp
claude plugin marketplace add Artekka/orcastration-kit
claude plugin install orchestration-kit@artekka-kits --scope project

# 2. Set up the repo and start the team — inside Claude; tell it your test command,
#    then accept "Seat + 2 siblings" and approve the one command it runs
claude
/orchestration-kit:kit-init
```

Three windows open: **Orca** (the seat) and **Sib1**, **Sib2** (siblings). Talk only to the seat:

```text
You> add rows for: <task A>; <task B>, and get them built
Orca> filed rows, assigned A to Sib1 and B to Sib2 (disjoint file fences)
      ... Sib1 and Sib2 each build in their own worktree and report ...
Orca> Sib2 reads Sib1's row (contract only); B goes to a fresh verifier agent, because the seat never makes a mutual pair; both PASS; merged one at a time, gate green
```

That's **team mode**, the default: the seat plans, assigns, routes verification and merges; the siblings build.
Walkthrough, Windows/macOS/Linux notes and failure modes: **[`docs/GETTING-STARTED.md`](docs/GETTING-STARTED.md)**.
How the whole loop fits together: **[`HOW-IT-WORKS.md`](HOW-IT-WORKS.md)**. Terms:
[`docs/GLOSSARY.md`](docs/GLOSSARY.md).

## Two modes

| Mode | Who coordinates | Start with |
|---|---|---|
| **Team** (default) | A **seat** session plans, assigns, routes verification, merges one row at a time, deploys in trains, recycles full sessions. You talk only to the seat | the Quickstart above; reopen later with `bash scripts/start-team.sh` (opens the seat + 2 siblings) — [GETTING-STARTED §3](docs/GETTING-STARTED.md#3-team-mode--who-does-what-the-default) |
| **Solo** (practice) | You, by hand, in the orchestrator's chair, with two sibling terminals and no seat. A practice ground for learning the loop by hand | [Practice mode](#practice-mode-solo-be-the-orchestrator-yourself) below |

## Practice mode (Solo): be the orchestrator yourself

Answer **Practice mode (Solo)** in `kit-init` (it starts nothing) and open two terminals yourself. You do what the seat
would do: file rows on the board, hand one to each sibling, let each verify the *other's* row, and reconcile.
You learn how rows are claimed with file fences, why every session builds in its own worktree, and why the verifier
sees only the contract. Once you trust the loop, graduate to a seat: when you are the one relaying between
windows or deciding who takes what, say "turn on the git guard" and run `bash scripts/start-team.sh`.

```bash
cd ~/projects/myapp
claude --name Dev1 /orchestration-kit:orient    # terminal 1
claude --name Dev2 /orchestration-kit:orient    # terminal 2
```

```text
Dev1> add rows to the board for: <task A>; <task B>
Dev1> claim Dev1-1 and build it in your own worktree
Dev2> claim Dev1-2 and build it in your own worktree
Dev2> verify Dev1-1 against its row — contract only, don't fix anything
Dev1> /orchestration-kit:reconcile Dev1-1
```

The guided demo, step by step: [`docs/GETTING-STARTED.md`, Practice](docs/GETTING-STARTED.md#4-practice-mode-solo-be-the-orchestrator-yourself).

This repo is a Claude Code **plugin** and its own **marketplace** (`artekka-kits`).
A project "depends" on the kit the way it depends on a package: install it, get the
workflow; upgrade it, get the newly distilled lessons.

## What's inside

| Piece | What it does |
|---|---|
| `skills/kit-init` | `/orchestration-kit:kit-init` — scaffold a project (board + overlay + scripts + CLAUDE.md section), idempotent |
| `skills/orchestrate` | the seat loop: banner, single-allocator, briefed rows, DAG + disjoint fences, sibling-session verification, one-at-a-time reconcile, wave-train deploys, LOG slot, sibling + seat recycling, approvals through the seat |
| `skills/orient` | session orientation: multi-session non-negotiables, five-bullet state, READY signal to the seat |
| `skills/board` | claim/update/close rows, per-session prefixes, the shared-checkout write recipe, status-not-narrative + archiving |
| `skills/verify-feature` | subagent verification — the fallback when no independent sibling session is free |
| `skills/orient-brief` | `/orchestration-kit:orient-brief <ROW>`: the lean start for a builder: the row's brief and the live seat banner arrive already loaded, then one READY line to the seat |
| `skills/assemble-train` · `skills/audit-train` | release trains: the seat lands approved rows one merge at a time with a dry run (`trial.sh`, `cptrial.sh`, `gsum.sh`) · a validator sweeps the finished train (`audit.sh` exits 0 when every merge is clean, 1 when a line needs explaining, 2 on a usage error) |
| `deploy_policy: ask \| auto-when-green` | the Deploy block of `ORCHESTRATION.md`: whether the seat asks you before every deploy (default) or deploys a green, audited train on its own and tells you after |
| `scripts/gate-throttle.sh` · `scripts/quiet-mode.sh` | run heavy commands through N machine-wide slots plus a priority slot (`gate_slots`); a second slot only while 3 GB of memory is available (`GATE_MIN_FREE_MB`); `--log <file>` writes the gate's log with the tested commit first and its exit code last · quiet mode holds every new run while you use the machine |
| `plugins/status-hud` | **optional** second plugin (`status-hud@artekka-kits`): a band or pane that shows every session's context fill, model and activity; `kit-init` asks (default: no), `/hud band\|pane\|off\|quiet` switches it. Host meters work on Linux and WSL only |
| `HOW-IT-WORKS.md` · `docs/how-it-works.html` | the guide to the whole loop: one diagram, one short section per system (what it does, why it exists, which setting changes it), and how to make it your own |
| `skills/falsify` | mutation-prove a guard/test can fail: commit GREEN first, diff-verified mutant, prediction written before the run, red observed unfiltered, byte-clean restore, re-green |
| `skills/reconcile` | land one worktree at a time onto main, push merges immediately, re-prove the gate there |
| `skills/retro` | session close-out; in orchestrator mode skips deploy and replies "retro complete" to the seat |
| `skills/post-feature` · `skills/bootstrap-project` | per-feature close-out checklist · bare directory → kit-adopted project |
| `agents/verifier.md` | the read-only verifier subagent (contract-only, four checks, structured verdict) |
| `hooks/` | SessionStart hook: fresh sessions in a repo with a board are told to orient and send READY to the seat; silent no-op elsewhere · `worktree-guard.sh` (PreToolUse on Edit/Write/MultiEdit/NotebookEdit): with `worktrees: enforced` in ORCHESTRATION.md, blocks edits in the main checkout except `docs/orchestration/**`, the log and the status doc; no-op otherwise (the default is `advised`) · `git-guard.sh` (PreToolUse on Bash): with `git_guard: on`, blocks `git stash` (except list/show), `git add -A`/`.`/`--all`, `git commit -a`, `git pull --rebase` with the safe alternative; no-op otherwise (default `off`). Tests: `bash tests/run.sh` |
| `scripts/start-team.sh` | open the seat + N siblings, each in its own window (terminal auto-detected), default names, skips any already running; `--dry-run`, `--terminal <backend>` / `--terminal list`, `--model` / `--effort` (always passed explicitly) |
| `scripts/recycle-sibling.sh` | replace a session with a fresh `claude --name X`: **in the same tab** when it runs under `sibling-shell.sh`, else a new window first and then SIGTERM the old one (`--new-tab` forces that); `--dry-run` (prints `mode:`), `--terminal`, `--account` (keeps each session on its own Claude Code account), `--model` / `--effort` (always passed, never inherited: the lane picks the model) |
| `scripts/sibling-shell.sh` | the respawn loop every tab the kit opens runs: starts `claude` as a child and, when `recycle-sibling.sh` leaves it a hand-off file, starts the next one in the same tab (crash-loop guard: two instant exits in a row stop it) |
| `scripts/lib-launch.sh` | the shared launcher both scripts source: detects the terminal backend — `tmux` (already inside tmux), `wsl-wt` / `wsl-conhost` (Windows + WSL), `macos-iterm` / `macos-terminal`, `gitbash-cmd`, `linux-<emulator>` (gnome-terminal, konsole, xfce4-terminal, kitty, alacritty, wezterm, foot, xterm, `$TERMINAL`, x-terminal-emulator), `tmux-detached` (SSH / headless), else `manual` (prints the commands, exits 2). Override: `--terminal` flag > `terminal:` in the team block > auto |
| `scripts/ctx-fill.py` | measure a session's REAL context fill from its transcript; `--window 1m\|200k` picks the marks (350K/400K on 1M, 120K/150K on 200K); a Haiku transcript implies 200K |
| `scripts/statusline-ctx.sh` | optional statusline: live context fill vs the 350K/400K marks (120K/150K on a 200K window) (yellow = self-report, red = hand over); enable via `templates/settings-snippets.md` |
| `scripts/bootstrap.sh` | the mechanical half of `bootstrap-project` (idempotent, `--dry-run`) |
| `templates/` | `AGENT_BOARD.md` (banner/handover/READY/archive shapes), `ORCHESTRATION.md` (gate, deploy, team, validator, doc paths), `AI_CONTEXT.md` + `build-log.md` (institutional memory), `CLAUDE-section.md`, `CLAUDE-slimness.md` (keep the always-loaded file slim), `briefs/` (row brief template + README), settings snippet, optional agents + memory starter |
| `docs/GETTING-STARTED.md` | first-timer walkthrough: install → kit-init → seat + siblings → recycling → failure modes |
| `docs/MULTI-ACCOUNT.md` | **optional:** run one team across several Claude Code accounts — `CLAUDE_CONFIG_DIR` per account, the shared session registry that makes cross-account messaging work, `--account` on both launch scripts |
| `docs/GLOSSARY.md` | the kit's vocabulary (seat, sibling, row, fence, gate, READ, wave train …) |
| `tests/` | `bash tests/run.sh` — git guard (every awk found), statusline, bootstrap idempotency + dry-run, multi-account launch, model/effort launch flags, ctx-fill marks |
| `docs/LESSONS.md` | the distilled incident-backed lessons — the upgrade payload |
| `docs/EXAMPLE-SESSION.md` | **a real annotated 12-hour session** — one seat, three sibling builders, two deploy trains, and the six things the seat got wrong |

**What the WORK/QUIET chip does and when you'll see it:** The chip is a switch for the kit's quiet mode. QUIET holds every NEW test/gate run started through `scripts/gate-throttle.sh` while you use the machine yourself; runs already going finish, and WORK lets new ones start normally. It only helps if your team runs its gate through that throttle, so the chip appears only when `scripts/quiet-mode.sh` exists in the session's directory (or quiet mode is already on). No throttle, no chip. If a press fails, the chip turns red and says `failed` for a minute, and the toast says why. `/hud help` repeats this, and `quietModeRequiresFile` changes the file it looks for (empty always shows the chip).

**Generic vs project-specific:** the kit never hardcodes a gate or deploy command.
Project specifics live in the consuming repo's `docs/orchestration/ORCHESTRATION.md`
(created by kit-init); every kit skill reads it first. That split is what makes lessons
portable: they land here once and every project pulls them on upgrade.

## Install

Per repo (recommended — the kit is active only in the repos you install it into).
Run from inside the repo:

```bash
claude plugin marketplace add Artekka/orcastration-kit   # or a local path
claude plugin install orchestration-kit@artekka-kits --scope project   # or --scope local
```

Even when installed more widely, its hooks stay silent unless the repo carries
the opt-in marker `docs/orchestration/.kit-hooks` (created by `kit-init`); the worktree guard
additionally needs `worktrees: enforced`.

Then, in each project: run `/orchestration-kit:kit-init` once (it copies the scripts into
`scripts/`), then `bash scripts/start-team.sh`. Step by step: [`docs/GETTING-STARTED.md`](docs/GETTING-STARTED.md).

Per-project (self-describing repo — teammates/machines get the plugin offered
automatically) — add to the project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "artekka-kits": {
      "source": { "source": "github", "repo": "Artekka/orcastration-kit" }
    }
  },
  "enabledPlugins": { "orchestration-kit@artekka-kits": true }
}
```

## Upgrade

```bash
claude plugin marketplace update artekka-kits
claude plugin update orchestration-kit
```

Read `CHANGELOG.md` for what changed. New lessons/hardenings = minor bump. A breaking
board-format/protocol change = major bump with a migration note. After upgrading, re-run
`/orchestration-kit:kit-init` in a project to be offered the template deltas (managed
markers keep your customizations safe).

## The team-mode workflow in one paragraph

The seat takes the board with an `ORCHESTRATOR ACTIVE` banner; siblings `/orchestration-kit:orient` and send
READY. `git fetch origin && git rebase origin/main` → read `docs/orchestration/AGENT_BOARD.md`
→ the seat assigns a row (message + board, disjoint file fences) → the sibling builds in its
**own worktree** (never `git add -A`, never `git stash`) → a **different sibling session**
verifies it against the contract only (PASS required) → the seat reconciles
**one worktree at a time** onto main, re-proving the overlay's gate with the literal
pass line → update the board, release the fence → deploy only via the exclusive DEPLOY
row claim, in wave trains. Full sessions retro, reply "retro complete", and are recycled.
Every rule traces to a paid-for incident — see `docs/LESSONS.md`.

## What's new

v0.9.0: Team mode (a seat + siblings) is the default start; Solo is now Practice mode, where you play the orchestrator by hand with two sibling terminals to learn the loop.

v0.8.2: the status HUD's WORK/QUIET chip shows only where the quiet-mode script exists, explains itself, and shows a failed press in red.
v0.8.1: the guide's loop diagram fits phones, and the guide explains `LAUNCH_LIVE_RECHECK` (a refused recycle).
v0.8.0: release trains (`assemble-train`, `audit-train`) and a `deploy_policy` setting (ask or auto-when-green),
the gate throttle and quiet mode, a session cap (`max_sessions`), non-blocking questions, the lean
`orient-brief` start, a recycle that refuses while the old session still has live shells, the optional
status HUD plugin, and a guide to the whole loop: [`HOW-IT-WORKS.md`](HOW-IT-WORKS.md). Details in `CHANGELOG.md`.
v0.7.0: recycling in place. A recycled session now restarts in the SAME terminal tab (a respawn wrapper, `scripts/sibling-shell.sh`, runs
every tab the kit opens), with a fresh context, an explicit model and its own account. A session started by hand moves over at
its next recycle. See "Recycling in place" below.
v0.6.0: a model per lane (`--model` / `--effort` on both launch scripts, always passed, never inherited),
lean builder starts (`/orchestration-kit:orient --brief <ROW>` from a brief file), per-window context marks
(120K/150K on a 200K window), optional multi-account teams, and a note on keeping `CLAUDE.md` slim.
v0.5.0: solo mode as the starting path, a git guard hook (on in team mode, off solo), the `falsify` skill, a
context-fill statusline, MIT LICENSE, tests (`bash tests/run.sh`), a glossary, and the worked
example session. Full history: [`CHANGELOG.md`](CHANGELOG.md).

## Recycling in place (v0.7.0)

`start-team.sh` and `recycle-sibling.sh` open each tab running `scripts/sibling-shell.sh <Name>`, which runs `claude` as its child. To
recycle, `recycle-sibling.sh <Name>` leaves the wrapper a small hand-off file (model, effort, permission mode, account, prompt) under
`~/.orchestration-kit/sessions/`, SIGTERMs only the old `claude`, and the wrapper starts the fresh one in the same tab. Same tab, no
stray windows, and nothing the old context held is lost, because a recycle only runs after the session replied "retro complete".
It opens a new tab instead (running the wrapper, so that session recycles in place next time) when there is no old process, the old
one was started by hand, you pass `--new-tab`, the machine has no `setsid` (macOS) and the seat is recycling itself, or the in-place
attempt times out (60 s; `RECYCLE_INPLACE_TIMEOUT`). The seat can recycle itself in place: the script prints a log path
(`~/.orchestration-kit/sessions/<Name>.recycle.log`), hands the work to a detached copy of itself and exits, and the copy ends the seat's
session about 2 s later (`RECYCLE_DETACH_DELAY`) so the seat's last command finishes first. `--dry-run` prints `mode: in-place` or `mode: new-tab`, and `detach: yes|no` for a self-recycle. `LAUNCH_NO_WRAPPER=1` opens tabs with a bare
`claude` as before.

**What is tested where.** The in-place path reads the process tree, so it needs `pgrep`: it is tested on Linux (and WSL), including
the `ps` code path that macOS uses (forced with `LAUNCH_NO_PROC=1`), but it has **not been run on a real Mac or in Git Bash**. Git
Bash (no `pgrep`) and the `manual` backend keep launching a bare `claude` and the old new-window recycle. On WSL a kit path that
contains a space cannot cross the `wt.exe` command line, so those tabs fall back to a bare `claude` too.

## Assumed plugins (user-level — documented, never copied)

The workflow assumes nothing beyond stock Claude Code. These user-level plugins are
routinely present on the origin setup and complement the kit, but the kit never installs
or requires them: `superpowers` (TDD/debugging discipline), `code-review`, a token/context
hygiene plugin. If a skill here references one, treat it as optional.

## Security

Report a vulnerability privately, never in a public issue: see [SECURITY.md](SECURITY.md) for the
supported versions, the private reporting channel and what to expect. CI scans every push and pull
request for secrets, and `tests/leak-guard.test.sh` keeps personal paths and keys out of the repo.

## Contributing

Pull requests are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) covers setup, `bash tests/run.sh`, the
branch and PR flow, commit messages and the optional pre-push secret scan. Everyone follows the
[Code of Conduct](CODE_OF_CONDUCT.md).

## Contributors

- Miles Brown (@MilesBrown34)

## PRS's changelog

Artekka's own changelog is in [CHANGELOG.md](CHANGELOG.md), his releases top down; the extras' lines sit there under
Unreleased. Below, one entry per release of this fork, newest first.

<!-- own-fork:changelog -->

### v1.0.0 (2026-10-23)
First official release: Artekka's 0.9.0 plus 20 extras.
<!-- /own-fork:changelog -->
