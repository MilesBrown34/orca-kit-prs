#!/usr/bin/env bash
# Tests for validator lanes (`validators:` in the team block, `--validators` on start-team.sh):
# v1-<name>, v2-<name> lanes that never build, drawn from the same name pool.
# Run: bash tests/validator-lanes.test.sh
# Nothing is launched: every call is --dry-run --terminal manual, in the same sandbox as
# tests/sibling-names.test.sh (HOME is a temp dir; real Windows/macOS/tmux tools are shadowed by stand-ins).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; ST="$ROOT/scripts/start-team.sh"
case "$ROOT" in *[[:space:]]*) echo "validator-lanes: SKIP (the kit's path has a space: $ROOT)"; exit 0 ;; esac
TMP="$(mktemp -d)"; pids=""
trap 'for p in $pids; do kill "$p" 2>/dev/null; done; rm -rf "$TMP"' EXIT
pass=0; fail=0
has() { case "$3" in *"$2"*) pass=$((pass+1)) ;; *) fail=$((fail+1)); echo "FAIL $1: want '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) fail=$((fail+1)); echo "FAIL $1: did not want '$2' in: $3" ;; *) pass=$((pass+1)) ;; esac; }
STUBS="$TMP/real-tool-stubs"; mkdir -p "$STUBS"
for t in wt.exe powershell.exe cmd.exe osascript tmux; do
  printf '#!/usr/bin/env bash\necho "%s $*" >> "%s"\nexit 99\n' "$t" "$TMP/REAL-TOOL-CALLED" > "$STUBS/$t"; chmod +x "$STUBS/$t"
done
lrun() { env HOME="$TMP" WSL_DISTRO_NAME= WSL_INTEROP= TMUX= "PATH=$STUBS:$PATH" "$@"; }
st() { lrun bash "$ST" --dry-run --terminal manual --repo "$ROOT" --seat ZzSeat "$@" 2>&1; echo "rc=$?"; }

# 1. Numbered builders plus one validator: the builders take the w-numbers, the validator the v-number.
out="$(TEAM_NAMES_SHUFFLE=0 st --siblings 2 --validators 1 --numbered w --names ZzMars,ZzVenus,ZzJuno)"
has "numbered: first builder" "LAUNCH w1-ZzMars" "$out"
has "numbered: second builder" "LAUNCH w2-ZzVenus" "$out"
has "numbered: the validator lane" "LAUNCH v1-ZzJuno" "$out"
hasnt "numbered: the validator is not a builder" "w3-ZzJuno" "$out"
has "numbered: dry-run shows the count" "validators=1" "$out"
has "numbered: exit 0" "rc=0" "$out"

# 2. A pool without numbering: builders keep bare names, the validator still gets v1-.
out="$(TEAM_NAMES_SHUFFLE=0 st --siblings 1 --validators 1 --names ZzMars,ZzVenus)"
has "bare pool: builder bare" "LAUNCH ZzMars" "$out"
has "bare pool: validator v1" "LAUNCH v1-ZzVenus" "$out"

# 3. No pool at all: Sib1 and v1-Sib.
out="$(st --siblings 1 --validators 1)"
has "no pool: builder" "LAUNCH Sib1" "$out"
has "no pool: validator" "LAUNCH v1-Sib" "$out"

# 4. Default is no validator lane, and the dry-run says so.
out="$(TEAM_NAMES_SHUFFLE=0 st --siblings 1 --names ZzMars,ZzVenus)"
hasnt "default: no v-lane" "LAUNCH v1-" "$out"
has "default: count shown" "validators=0" "$out"

# 5. From the team block of a repo's ORCHESTRATION.md.
R="$TMP/repo"; mkdir -p "$R/docs/orchestration"; git -C "$R" init -q
printf 'team:\n  seat:             ZzSeat\n  names:            ZzJanus,ZzPluto,ZzCeres\n  siblings:         1\n  numbered:         w\n  validators:       1\n' > "$R/docs/orchestration/ORCHESTRATION.md"
out="$(TEAM_NAMES_SHUFFLE=0 lrun bash "$ST" --dry-run --terminal manual --repo "$R" 2>&1; echo "rc=$?")"
has "team block: builder" "LAUNCH w1-ZzJanus" "$out"
has "team block: validator" "LAUNCH v1-ZzPluto" "$out"
has "team block: config source shown" "config: team: block" "$out"
has "team block: exit 0" "rc=0" "$out"

# 6. A running v-lane is kept (SKIP), counts as the validator, and is never redrawn as a builder.
(exec -a "claude --name v1-ZzJuno" sleep 60) & pids="$pids $!"
for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -f '^claude --name v1-ZzJuno( |$)' >/dev/null && break; sleep 0.2; done
out="$(TEAM_NAMES_SHUFFLE=0 st --siblings 1 --validators 1 --numbered w --names ZzCeres,ZzJuno,ZzVesta)"
has "running v-lane: kept" "SKIP   v1-ZzJuno" "$out"
has "running v-lane: builder drawn from the rest" "LAUNCH w1-ZzCeres" "$out"
hasnt "running v-lane: no second validator" "LAUNCH v1-ZzVesta" "$out"
hasnt "running v-lane: not redrawn as a builder" "ZzJuno" "$(printf '%s\n' "$out" | grep '^LAUNCH')"
has "running v-lane: exit 0" "rc=0" "$out"

# 7. Refusals, all exit 64: the letter v for builders, a pool too small once validators count, a bad count.
out="$(st --siblings 1 --validators 1 --numbered v --names ZzMars,ZzVenus)"
has "numbered v: refused" "rc=64" "$out"
has "numbered v: says why" "validator lanes' letter" "$out"
out="$(st --siblings 2 --validators 1 --names ZzMars,ZzVenus)"
has "small pool: refused" "rc=64" "$out"
has "small pool: counts validators" "for 2 siblings and 1 validators" "$out"
out="$(st --siblings 1 --validators x)"
has "bad count: refused" "rc=64" "$out"

echo "validator-lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
