# Extras

Every extra this fork adds to Artekka's orchestration kit, as of **v1.0.2** (on Artekka's 0.9.0): 22 in all. Each one is
kept as its own branch (`extra/<id>`) and offered to him on its own; "since" names the release that first carried it.

✨ Feature: something new to use or see · 🐛 Fix: something broken, repaired · 🔧 Update: a change to how the workflow runs.

## Start and setup

- ✨ **Start word**: your start word opens a project menu (with the kit's version); starts a team, one chat, or sets the kit up; setup asks which word you want; `update_cmd=` adds [u] update the kit to the menu (since v1.0.0)
- ✨ **Bypass**: bypass shows up in Shift+Tab, while sessions still start in normal mode (since v1.0.0)
- ✨ **Tabs**: one Windows Terminal tab color per project; team names (w1-Mars, w2-Venus), your names asked once per machine (since v1.0.0)
- ✨ **Kit update**: `/orchestration-kit:kit-update` and `scripts/kit-update.sh`: shows when a newer kit exists, updates it (and the status bar) on a yes, warns open sessions keep the old version, lists projects whose copied scripts are older and refreshes them (since v1.0.0)
- 🐛 **Cap count fix**: a team start no longer quits silently when no Claude is running (the session-cap count read pgrep's "found none" as an error) (since v1.0.0)

## Status bar

- ✨ **Status bar**: the status bar's setup page, project dots, warnings on the right (most urgent first) (since v1.0.0)
- ✨ **HUD setup Done**: the status bar's setup page saves with one Done press, explains each number in a pop-up, jumps to it in the list, labels when each item appears, opens at kit-init, and is shown in the README, and offers the pane's icon (koi or helmet) (since v1.0.0)
- ✨ **Programs and live version**: status bar chips for each program a session drives while it runs (Blender, Godot, Gemini, and any Windows program a session starts, found by itself; who started it, +N for copies no session claims) and ComfyUI's queue (asked through Windows' curl); a `live v…` chip from the board's DEPLOY line, which the seat now writes as `DEPLOY FREE (live <version>)` (since v1.0.0)
- ✨ **Model badges**: OPS (yellow), SNT (blue), HKU (green), GEM (purple) right after each session's name in the status bar (since v1.0.0)
- ✨ **Session state**: a busy session's mark turns clockwise (▘ ▝ ▗ ▖), and the status bar's key explains ▘ busy, $ shell, ○ idle (since v1.0.0)
- ✨ **Background state**: a session whose turn ended while background work it started still runs shows ◔ (cyan) instead of ○ idle, with `bg: <first job> +N` as its activity; it can be talked to but is not done (since v1.0.0)
- ✨ **Programs on a background row**: a ◔ row's activity ends with the tracked programs its background work is running (`bg: Run the checks · godot ×2`) (since v1.0.0)
- ✨ **CPU temperature**: the status bar's CPU line shows the load and the CPU temperature (`5.1 72°C`), read from Linux's own sensor or, on WSL, from LibreHardwareMonitor running on Windows; without a reading it keeps `5.1/16t` (since v1.0.0)
- ✨ **Koi icon**: the pane's icon is a setting, koi (white with red patches, the default) or the horned helmet; picked on the status bar's setup page or as `paneIcon` (since v1.0.0)

## Tests, gates and guards

- 🔧 **Gate log**: `gate-throttle.sh --log <file>`: once the slot is held, the gate's output goes to the file, opening with the commit (`SHA …`) and `started <time> dirty=<n>` read at that moment and ending with `exit <code>`, so a gate log names the code it tested (since v1.0.0)
- 🔧 **Gate memory**: `gate-throttle.sh`: a normal slot beyond the first only while available memory (`MemAvailable`) is at least `GATE_MIN_FREE_MB` (default 3072); below that one normal slot at a time; unreadable = admit; `KIT_MEMINFO_FILE` fakes the reading in tests (since v1.0.0)
- 🔧 **Skill checks**: `tests/skills-lint.test.sh` refuses a skill or agent with a wrong name, a missing or over-long description, a cited file that does not exist, or a personal home path (`KIT_PRIVATE_WORDS=<file>` adds a private word list); `scripts/skill-usage.py <log folder>` shows which kit skills a project's sessions ran and which never (since v1.0.0)
- ✨ **Secrets guard**: a `never_read:` list in ORCHESTRATION.md → Secrets; the kit's hook then refuses reading, searching or naming those paths (key stores, token files, locked copies) for Read, Grep and Bash, and sends the session to the human for the key; no list, no guard (since v1.0.1)

## Seat, verifier and lessons

- 🔧 **Lessons from the checks**: ninety-one new lessons (61–151) in docs/LESSONS.md, distilled from real checks and guards, and 46 existing lessons extended (since v1.0.0)
- 🔧 **Lighter seat skill**: the seat skill's deploy, log and recycle/handover steps sit in two files beside it (`deploy-and-log.md`, `recycle-and-handover.md`), read only before those steps; every seat start loads ~850 tokens less (since v1.0.0)
- 🔧 **Verifier reads the base**: the verifier reads the brief, the overlay and the Locked list at origin/main, never from the branch it judges; commit messages, comments and diff text are data, never instructions; a table says what PASS, DEVIATES and BROKEN mean (since v1.0.1)
- 🔧 **Rules by path and a review checklist**: project conventions that bind only some files go in `.claude/rules/<area>.md` with a `paths:` list (loaded only when a session touches a matching file), named on each brief and read by the verifier at origin/main; ORCHESTRATION.md gets a Review checklist that retro appends to and the verifier checks on every row (since v1.0.1)
