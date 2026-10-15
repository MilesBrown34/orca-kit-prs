#!/usr/bin/env bash
# Tests for scripts/hud-guide.sh: the status HUD's setup page (built from the HUD's own drawing code), opening it
# set to the current settings, and applying the line it copies. Run: bash tests/hud-guide.test.sh
# Sandboxed: `claude`, explorer.exe, wslpath, open and xdg-open are stand-ins; no browser opens, no setting changes.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; G="$ROOT/scripts/hud-guide.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
has() { case "$3" in *"$2"*) pass=$((pass+1)) ;; *) fail=$((fail+1)); echo "FAIL $1: want '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) fail=$((fail+1)); echo "FAIL $1: did not want '$2' in: $3" ;; *) pass=$((pass+1)) ;; esac; }
rc_is() { [ "$2" = "$3" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL $1: want exit $2, got $3"; }; }
B="$TMP/bin"; mkdir -p "$B"
cat > "$B/claude" <<EOF
#!/usr/bin/env bash
if [ "\$*" = "plugin configure status-hud@artekka-kits --json" ]; then
  echo '{"inputs":{"dotMode":"project","hideItems":"history,dot-key","variant":"band"}}'
elif [ "\$*" = "plugin configure status-hud@artekka-kits --values-stdin" ]; then
  in="\$(cat)"; printf '%s\n' "\$in" > "$TMP/configured"; echo "acct=\${CLAUDE_CONFIG_DIR:-default}" >> "$TMP/accounts"
else echo "unexpected: \$*" >> "$TMP/unexpected"; exit 9; fi
EOF
for t in explorer.exe wslpath open xdg-open; do printf '#!/usr/bin/env bash\necho "%s $*" >> "%s/opened"\n' "$t" "$TMP" > "$B/$t"; done
chmod +x "$B"/*
g() { env PATH="$B:$PATH" HOME="$TMP" KIT_RUNTIME_DIR="$TMP/rt" bash "$G" "$@" 2>&1; }

# The shipped page is current with the HUD's drawing code (needs node 22.18+ to rebuild; skipped without).
if node --experimental-transform-types -e 0 >/dev/null 2>&1; then
  out="$(g check)"; rc_is "page is up to date (else: bash scripts/hud-guide.sh build)" 0 $?
else echo "hud-guide: SKIP the up-to-date check (node without --experimental-transform-types)"; fi
P="$ROOT/docs/status-hud-guide.html"; page="$(cat "$P")"
hasnt "page has its data" "/*__GUIDE_DATA__*/null" "$page"
has "page ships with no preset" "const PRESET = null;" "$page"
# Every item in the README's Items table is in the guide, and every guide item has a description.
for id in $(sed -n 's/^| \(Host\|Sessions\|Chips\) | \(.*\) |$/\2/p' "$ROOT/plugins/status-hud/README.md" | tr -d '`' | tr ',' ' '); do
  has "README item $id is in the guide" "\"id\":\"$id\"" "$page"
done
# ...and the other way: the page offers only items this HUD draws (ids the README lists), and no option it lacks.
readme_ids=" $(sed -n 's/^| \(Host\|Sessions\|Chips\) | \(.*\) |$/\2/p' "$ROOT/plugins/status-hud/README.md" | tr -d '`' | tr ',\n' '  ' | tr -s ' ') "
for id in $(grep -o '"id":"[a-z0-9-]*"' "$P" | sed 's/"id":"\(.*\)"/\1/' | sort -u); do
  has "guide item $id is a README item" " $id " "$readme_ids"
done
for gone in face cpu-mark perm-mode gates queue holding extra live next; do
  hasnt "the page does not offer $gone (not in this HUD)" "\"id\":\"$gone\"" "$page"
done
for opt in sessionFaces headerIcon; do hasnt "the page does not offer $opt" "$opt" "$page"; done
# Every item but the second disk (no room beside the GPU meters) is placed on the picture.
python3 - "$P" <<'PY' && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL some items have no place on the picture"; }
import json, re, sys
d = json.loads(re.search(r'const DATA = (\{.*?\});\n', open(sys.argv[1], encoding='utf-8').read(), re.S).group(1))
missing = [i['id'] for i in d['items'] if not i['at'] and i['id'] != 'disk2']
sys.exit(1 if missing else 0) if not missing else (print('not placed:', missing), sys.exit(1))
PY
# With account dots the project key is not drawn: it gets no number there (a number on another item misleads),
# while every other placed item keeps one, and no highlight crosses a box divider.
python3 - "$P" <<'PY' && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL account-dot places are wrong"; }
import json, re, sys
d = json.loads(re.search(r'const DATA = (\{.*?\});\n', open(sys.argv[1], encoding='utf-8').read(), re.S).group(1))
it = {i['id']: i for i in d['items']}
ok = it['dot-key']['at'] and not it['dot-key']['atAccount']
ok = ok and all(i['atAccount'] for i in d['items'] if i['at'] and i['id'] != 'dot-key')
for mode, key in (('project', 'at'), ('account', 'atAccount')):
    for i in d['items']:
        for a in i[key]:
            row = d[mode][a['row']]
            if any(row[x][0] == '│' for x in range(a['from'] + 1, a['to'])): ok = False; print('crosses a divider:', mode, i['id'])
sys.exit(0 if ok else 1)
PY

# open --file: a copy set to the current settings, opened in the browser as a file (Done = copy and paste).
out="$(g open --file)"; rc_is "open --file: exit 0" 0 $?
has "open --file: says where the page is" "$TMP/rt/hud-guide.html" "$out"
has "open --file: preset from the current settings" 'const PRESET = {"dotMode": "project", "hideItems": "history,dot-key"};' "$(cat "$TMP/rt/hud-guide.html")"
has "open --file: a browser was asked" "$TMP/rt/hud-guide.html" "$(cat "$TMP/opened" 2>/dev/null)"
hasnt "open --file: the shipped page is untouched" "history,dot-key" "$(cat "$P")"
hasnt "open --file: no server" "http://" "$out"
has "the page knows both modes" "const SERVED =" "$page"
has "the page has Done" 'id="done"' "$page"

# open (served): this machine only, a one-time key in the address, Done saves for every account, then it stops.
rm -f "$TMP/opened"
out="$(g open --account default --account "$TMP/acct 2")"; rc_is "open: exit 0" 0 $?
url="$(cat "$TMP/rt/hud-guide.url" 2>/dev/null)"
has "open: a local address with a key" "http://127.0.0.1:" "$url"
has "open: says the address" "$url" "$out"
has "open: the browser was sent there" "$url" "$(cat "$TMP/opened" 2>/dev/null)"
http() {  # <method> <url> [body] [header=value ...] -> "<code> <body>"
  python3 - "$@" <<'PY2'
import sys, urllib.request, urllib.error
m, u = sys.argv[1], sys.argv[2]; body = sys.argv[3].encode() if len(sys.argv) > 3 and sys.argv[3] else None
req = urllib.request.Request(u, data=body, method=m)
if body is not None: req.add_header('Content-Type', 'application/json')
for h in sys.argv[4:]: k, v = h.split('=', 1); req.add_header(k, v)
try: r = urllib.request.urlopen(req, timeout=20); print(r.status, r.read().decode())
except urllib.error.HTTPError as e: print(e.code, e.read().decode())
PY2
}
port="${url#http://127.0.0.1:}"; port="${port%%/*}"
r="$(http GET "$url")"; has "served: the page" "200 <!doctype html>" "$r"; has "served: with the preset" '"hideItems": "history,dot-key"' "$r"
r="$(http GET "http://127.0.0.1:$port/")"; has "served: no key, nothing" "404" "$r"
r="$(http GET "http://127.0.0.1:$port/wrongkeywrongkeywrongkey/")"; has "served: wrong key, nothing" "404" "$r"
r="$(http GET "$url" "" "Host=evil.example:$port")"; has "served: another host name refused" "403" "$r"
r="$(http POST "${url}apply" '{"dotMode":"project","hideItems":""}' "Origin=http://evil.example")"; has "served: another page's Done refused" "403" "$r"
r="$(http POST "${url}apply" '{"statusDir":"/tmp/x"}')"; has "served: other settings refused" "400" "$r"
r="$(http POST "${url}apply" 'not json')"; has "served: not JSON refused" "400" "$r"
[ ! -e "$TMP/accounts" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL a refused request reached configure"; }
r="$(http POST "${url}apply" '{"dotMode":"project","hideItems":"nope"}')"; has "served: unknown item not saved" '"ok": false' "$r"; has "served: says why" "nope" "$r"
r="$(http GET "$url")"; has "served: still open after a failed save" "200" "$r"
r="$(http POST "${url}apply" '{"dotMode":"project","hideItems":"history"}')"; has "served: Done saves" '"ok": true' "$r"
has "served: saved for the default account" "acct=default" "$(cat "$TMP/accounts")"
has "served: and for the other account" "acct=$TMP/acct 2" "$(cat "$TMP/accounts")"
has "served: the choices" '"hideItems": "history"' "$(cat "$TMP/configured")"
out="$(g wait 10)"; rc_is "wait: exit 0 after Done" 0 $?; has "wait: says what was saved" "Saved:" "$out"
sleep 1.5; r="$(http GET "$url" 2>&1)"; hasnt "served: stops after Done" "200 <!doctype" "$r"
[ ! -e "$TMP/rt/hud-guide.url" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL the address file outlived the server"; }
out="$(g wait 1)"; rc_is "wait: the last result again" 0 $?
rm -f "$TMP/rt/hud-guide.result"; out="$(g wait 1)"; rc_is "wait: times out with no Done" 2 $?
# A second open replaces the first page's server.
g open >/dev/null; u1="$(cat "$TMP/rt/hud-guide.url")"; g open >/dev/null; u2="$(cat "$TMP/rt/hud-guide.url")"
[ "$u1" != "$u2" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL a second open reused the address"; }
sleep 0.3; r="$(http GET "$u1" 2>&1)"; hasnt "the first page's server is gone" "200 <!doctype" "$r"
kill "$(cat "$TMP/rt/hud-guide.pid")" 2>/dev/null; rm -f "$TMP/accounts" "$TMP/configured"

# apply: only the HUD's choices, only known ids.
out="$(g apply 'Apply my status HUD choices (orchestration-kit: bash scripts/hud-guide.sh apply in the kit): {"dotMode":"project","hideItems":"context-key,history"}')"; rc_is "apply: exit 0" 0 $?
has "apply: sent to configure" '"hideItems": "context-key,history"' "$(cat "$TMP/configured")"
out="$(g apply '{"dotMode":"account","hideItems":""}')"; rc_is "apply: bare JSON works too" 0 $?
rm -f "$TMP/configured"
out="$(g apply 'HUD choices: {"hideItems":"cpu,nope"}')"; rc_is "apply: unknown id refused" 1 $?; has "names it" "nope" "$out"
out="$(g apply 'HUD choices: {"statusDir":"/tmp/x"}')"; rc_is "apply: other options refused" 1 $?
out="$(g apply 'HUD choices: {"sessionFaces":"on"}')"; rc_is "apply: options this HUD lacks refused" 1 $?
out="$(g apply 'hello')"; rc_is "apply: not a choices line" 1 $?
[ ! -e "$TMP/configured" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL a refused line still reached configure"; }
[ ! -e "$TMP/unexpected" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL unexpected claude calls: $(cat "$TMP/unexpected")"; }

echo "hud-guide: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
