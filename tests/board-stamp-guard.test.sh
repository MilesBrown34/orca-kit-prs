#!/usr/bin/env bash
# Tests for hooks/board-stamp-guard.py: a new HH:MMZ stamp more than 2 minutes ahead of the (faked) clock is
# refused on the board; on time, earlier, late yesterday, an unchanged old stamp, other files and repos
# without the opt-in marker pass. Run: bash tests/board-stamp-guard.test.sh   (needs python3, git)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; H="$ROOT/hooks/board-stamp-guard.py"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL $*"; }
if ! command -v python3 >/dev/null 2>&1; then echo "board-stamp-guard: SKIP (no python3)"; exit 0; fi
B="$TMP/repo/docs/orchestration/AGENT_BOARD.md"
git init -q -b main "$TMP/repo"; mkdir -p "$(dirname "$B")"; printf '# Board\n- row X done 09:58Z\n' > "$B"
edit() {  # <now> <old> <new> [file] -> hook output
  python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":sys.argv[2],"new_string":sys.argv[3]}}))' \
    "${4:-$B}" "$2" "$3" | BOARD_STAMP_NOW="$1" python3 "$H"
}
denied()  { case "$2" in *'"deny"'*) ok ;; *) bad "$1: want deny, got '$2'" ;; esac; }
allowed() { [ -z "$2" ] && ok || bad "$1: want allow, got '$2'"; }

# without the opt-in marker nothing is checked
allowed "no marker: off" "$(edit 10:00 'x' '- row Y 10:30Z')"
: > "$TMP/repo/docs/orchestration/.kit-hooks"
denied  "30 min ahead" "$(edit 10:00 'x' '- row Y 10:30Z')"
denied  "the refusal names the clock" "$(edit 10:00 'x' '- row Y 10:30Z' | grep -o 'now 10:00Z')$(edit 10:00 'x' '- row Y 10:30Z')"
allowed "on time" "$(edit 10:00 'x' '- row Y 10:00Z')"
allowed "2 min ahead is clock skew" "$(edit 10:00 'x' '- row Y 10:02Z')"
denied  "3 min ahead" "$(edit 10:00 'x' '- row Y 10:03Z')"
allowed "earlier today" "$(edit 10:00 'x' '- row Y 08:15Z')"
allowed "late yesterday, just after midnight" "$(edit 00:10 'x' '- row Y 23:50Z')"
denied  "ahead across midnight" "$(edit 23:55 'x' '- row Y 00:20Z')"
allowed "an old stamp kept in the edited text" "$(edit 10:00 '- row X 11:30Z' '- row X closed 11:30Z')"
allowed "an approximation is not a stamp" "$(edit 10:00 'x' '- row Y ~3xZ')"
allowed "another file" "$(edit 10:00 'x' '- 10:30Z' "$TMP/repo/docs/notes.md")"
# Write compares with the file on disk: its existing 09:58Z stays allowed, a new future one is refused
w() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]}}))' "$B" "$2" | BOARD_STAMP_NOW="$1" python3 "$H"; }
allowed "Write keeps an old stamp" "$(w 09:00 "$(cat "$B")")"
denied  "Write adds a future stamp" "$(w 09:00 "$(cat "$B")"$'\n- new 09:30Z')"
# bad input never breaks the call
allowed "garbage stdin" "$(echo 'not json' | python3 "$H")"

echo "board-stamp-guard: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
