#!/usr/bin/env bash
# hud-guide.sh — the status HUD's setup page: every item numbered on a picture, Keep / Remove for each,
# the dot choice, and Done (orchestration-kit). kit-init opens it after installing the HUD.
#
# Usage:
#   hud-guide.sh open [--account DIR]... [--file]
#                                 open the page in your browser, set to your current HUD settings. It is served
#                                 to this machine only (scripts/hud-guide-server.py), so Done saves the choices for
#                                 each --account (a CLAUDE_CONFIG_DIR, or "default"; none = the current account).
#                                 --file: open it as a plain file instead; Done then copies a line to paste to Claude
#                                 --try: try it safely: Done only reports what it would save; no setting changes
#   hud-guide.sh wait [SECONDS]   wait (default 3600 s) for Done on the page opened by open; print what was saved
#   hud-guide.sh apply [--try] '<line>'
#                                 save the line the page copied ("Apply my status HUD choices ...: {...}") to the HUD's settings
#   hud-guide.sh build            (kit developers) rebuild docs/status-hud-guide.html from the HUD's drawing code
#   hud-guide.sh check            (tests) exit 1 when docs/status-hud-guide.html is out of date
# open and apply use `claude plugin configure status-hud@artekka-kits` (CLAUDE_CONFIG_DIR picks the account).
# apply accepts only dotMode and hideItems with known item ids (the items this HUD draws); options it is not
# given keep their values. build and check need node 22.18 or later.
# Exit 0 done, 1 failed or refused, 2 wait timed out, 64 usage.
set -uo pipefail

KIT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
HUD="$KIT/plugins/status-hud"
PAGE="$KIT/docs/status-hud-guide.html"
PLUGIN="status-hud@artekka-kits"
RT="${KIT_RUNTIME_DIR:-$HOME/.orchestration-kit/runtime}"
usage() { sed -n '5,20p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 64; }
browse() {  # <file or URL>: the system's browser; says so when none
  if command -v wslpath >/dev/null 2>&1 && command -v explorer.exe >/dev/null 2>&1; then
    case "$1" in http*) explorer.exe "$1" ;; *) explorer.exe "$(wslpath -w "$1")" ;; esac >/dev/null 2>&1 || true
  elif command -v open >/dev/null 2>&1 && [ "$(uname -s)" = Darwin ]; then open "$1"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$1" >/dev/null 2>&1 &
  else echo "Open that in your browser."; fi
}

# render <preset json|null>: the page, with the guide data and the preset filled in, on stdout
render() {
  local data
  data="$(cd "$HUD/scripts" && node --no-warnings --experimental-transform-types --import ./ts-resolve.mjs guide.ts)" || { echo "hud-guide: node could not draw the HUD (needs node 22.18+)" >&2; return 1; }
  DATA="$data" PRESET="$1" python3 -c '
import os, sys
t = open(sys.argv[1], encoding="utf-8").read()
t = t.replace("/*__GUIDE_DATA__*/null", os.environ["DATA"]).replace("/*__PRESET__*/null", os.environ["PRESET"])
sys.stdout.write(t)' "$HUD/scripts/guide-template.html"
}
ids() { sed -n "s/^  { id: '\([a-z0-9-]*\)'.*/\1/p" "$HUD/scripts/guide.ts"; }

case "${1:-}" in
  build) render null > "$PAGE.tmp" && mv "$PAGE.tmp" "$PAGE" && echo "wrote $PAGE" ;;
  check)
    render null > "${TMPDIR:-/tmp}/hud-guide.$$" || exit 1
    if cmp -s "${TMPDIR:-/tmp}/hud-guide.$$" "$PAGE"; then rm -f "${TMPDIR:-/tmp}/hud-guide.$$"; echo "hud-guide: up to date"
    else rm -f "${TMPDIR:-/tmp}/hud-guide.$$"; echo "hud-guide: docs/status-hud-guide.html is out of date; run: bash scripts/hud-guide.sh build" >&2; exit 1; fi ;;
  open)
    shift; accts=(); asfile=; try=()
    while [ $# -gt 0 ]; do case "$1" in
      --account) [ $# -ge 2 ] || usage; accts+=("$2"); shift 2 ;;
      --file) asfile=1; shift ;;
      --try) try=(--try); shift ;;
      *) usage ;; esac; done
    [ ${#accts[@]} -gt 0 ] || accts=("${CLAUDE_CONFIG_DIR:-default}")
    out="$RT/hud-guide.html"; mkdir -p "$RT"
    # The page starts from the first account's settings.
    if [ "${accts[0]}" = default ]; then pre_env=(env -u CLAUDE_CONFIG_DIR); else pre_env=(env CLAUDE_CONFIG_DIR="${accts[0]}"); fi
    preset="$("${pre_env[@]}" claude plugin configure "$PLUGIN" --json 2>/dev/null | python3 -c '
import json, sys
try: i = json.load(sys.stdin).get("inputs", {})
except Exception: print("null"); sys.exit()
print(json.dumps({k: i.get(k, "") for k in ("dotMode", "hideItems")}))' 2>/dev/null)"
    [ -n "$preset" ] || preset=null
    # The shipped page with the preset swapped in: no node needed on the user's machine.
    PRESET="$preset" python3 -c '
import os, sys
t = open(sys.argv[1], encoding="utf-8").read()
sys.stdout.write(t.replace("const PRESET = null;", "const PRESET = " + os.environ["PRESET"] + ";", 1))' "$PAGE" > "$out" || exit 1
    if [ -n "$asfile" ]; then echo "The HUD setup page: $out"; browse "$out"; exit 0; fi
    # Served: one page at a time, so a page left open earlier stops answering.
    [ -f "$RT/hud-guide.pid" ] && kill "$(cat "$RT/hud-guide.pid")" 2>/dev/null
    rm -f "$RT/hud-guide.url" "$RT/hud-guide.result"
    aargs=(); for a in "${accts[@]}"; do aargs+=(--account "$a"); done
    nohup python3 "$KIT/scripts/hud-guide-server.py" --page "$out" --guide "$KIT/scripts/hud-guide.sh" --state "$RT" \
      "${aargs[@]}" "${try[@]}" >"$RT/hud-guide.log" 2>&1 &
    echo $! > "$RT/hud-guide.pid"
    for _ in $(seq 50); do [ -s "$RT/hud-guide.url" ] && break; sleep 0.1; done
    if [ ! -s "$RT/hud-guide.url" ]; then
      echo "hud-guide: the page's server did not start ($(tail -1 "$RT/hud-guide.log" 2>/dev/null)); opening it as a file: press Copy my choices and paste the line to Claude" >&2
      echo "The HUD setup page: $out"; browse "$out"; exit 0
    fi
    url="$(cat "$RT/hud-guide.url")"
    if [ ${#try[@]} -gt 0 ]; then url="${url}?try=1"; echo "The HUD setup page, try mode: $url (Done only shows what it would save; your settings stay as they are)"
    else echo "The HUD setup page: $url (this machine only; press Done on it to save)"; fi
    browse "$url" ;;
  wait)
    secs="${2:-3600}"; case "$secs" in *[!0-9]*|'') usage ;; esac
    end=$((SECONDS + secs))
    while [ ! -s "$RT/hud-guide.result" ]; do
      [ $SECONDS -lt $end ] || { echo "hud-guide: no Done on the setup page within $secs s (it stays open until it times out)"; exit 2; }
      sleep 1
    done
    status="$(head -1 "$RT/hud-guide.result")"; tail -n +2 "$RT/hud-guide.result"
    case "$status" in ok) exit 0 ;; timeout) exit 2 ;; *) exit 1 ;; esac ;;
  apply)
    shift; dry=; [ "${1:-}" = --try ] && { dry=1; shift; }
    [ $# -ge 1 ] || usage
    vals="$(LINE="$1" IDS="$(ids | tr '\n' ',')" python3 -c '
import json, os, sys
line = os.environ["LINE"].strip()
if "{" in line: line = line[line.index("{"):]  # the line from the page starts with what to do with it
try: v = json.loads(line)
except Exception: sys.exit("not a HUD choices line: " + os.environ["LINE"][:80])
known = set(filter(None, os.environ["IDS"].split(",")))
out = {}
for k, x in v.items():
    if k == "dotMode" and x in ("account", "project"): out[k] = x
    elif k == "hideItems" and isinstance(x, str):
        bad = [i for i in x.split(",") if i and i not in known]
        if bad: sys.exit("unknown item ids: " + ",".join(bad))
        out[k] = x
    else: sys.exit("not a HUD choice: %s=%r" % (k, x))
print(json.dumps(out))')" || exit 1
    if [ -n "$dry" ]; then echo "Try mode, nothing saved. Done would save: $vals"; exit 0; fi
    printf '%s' "$vals" | claude plugin configure "$PLUGIN" --values-stdin || { echo "hud-guide: claude plugin configure failed (its message is above)" >&2; exit 1; }
    echo "Saved: $vals. The HUD redraws with it from each session's next start." ;;
  *) usage ;;
esac
