#!/usr/bin/env bash
# Tests for hooks/secrets-guard.sh: the listed paths are refused for Read, Grep and a Bash command naming them;
# everything else passes; without the marker or the list the hook is silent. Run: bash tests/secrets-guard.test.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; HOOK="$ROOT/hooks/secrets-guard.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
H="$TMP/home"; mkdir -p "$H/.config/msm/secrets" "$H/proj/src"; echo k > "$H/.config/msm/secrets/api.key"; echo lock > "$H/.config/msm/secrets.tar.gpg"; echo src > "$H/proj/src/a.ts"; echo pem > "$H/proj/cert.pem"
call() {  # <tool> <json tool_input> [cwd] -> "deny" or "allow"
  local out
  out="$(printf '{"session_id":"t","hook_event_name":"PreToolUse","cwd":"%s","tool_name":"%s","tool_input":%s}' "${3:-$H/proj}" "$1" "$2" | bash "$HOOK")"
  case "$out" in *'"permissionDecision":"deny"'*) echo deny ;; *) echo allow ;; esac
}
want() { local got; got="$(call "$2" "$3" "${4:-}")"; if [ "$got" = "$1" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL want $1 got $got: $2 $3"; fi; }
CONF="$TMP/ORCH.md"
cat > "$CONF" <<EOC
## Secrets

never_read:
  - ~/.config/msm/secrets/
  - \$HOME/.config/msm/secrets.tar.gpg   # the locked copy
  - *.pem
EOC
export SECRETS_GUARD_CONF="$CONF" SECRETS_GUARD_HOME="$H"
# --- Read
want deny  Read '{"file_path":"'"$H"'/.config/msm/secrets/api.key"}'
want deny  Read '{"file_path":"~/.config/msm/secrets/api.key"}'
want deny  Read '{"file_path":"'"$H"'/.config/msm/secrets.tar.gpg"}'
want deny  Read '{"file_path":"'"$H"'/proj/cert.pem"}'
want deny  Read '{"file_path":"cert.pem"}'
want allow Read '{"file_path":"'"$H"'/proj/src/a.ts"}'
want allow Read '{"file_path":"src/a.ts"}'
want allow Read '{"file_path":"'"$H"'/.config/msm/secretsfile"}'
want allow Read '{"file_path":"'"$H"'/.config/msm/bin/tool.py"}'
# --- Grep: inside a listed path, or a sweep that would pass through one
want deny  Grep '{"pattern":"KEY","path":"'"$H"'/.config/msm/secrets"}'
want deny  Grep '{"pattern":"KEY","path":"'"$H"'/.config"}'
want allow Grep '{"pattern":"KEY","path":"'"$H"'/proj"}'
want allow Grep '{"pattern":"KEY"}'
# --- Bash: the command text names a listed path, in any of its spellings
want deny  Bash '{"command":"cat '"$H"'/.config/msm/secrets/api.key"}'
want deny  Bash '{"command":"cat ~/.config/msm/secrets/api.key | head"}'
want deny  Bash '{"command":"gpg -d $HOME/.config/msm/secrets.tar.gpg"}'
want deny  Bash '{"command":"ls ~/.config/msm/secrets"}'
want allow Bash '{"command":"ls ~/.config/msm"}'
want allow Bash '{"command":"cat src/a.ts"}'
want allow Bash '{"command":"python3 -I ~/.config/msm/bin/tool.py"}'
want allow Bash '{"command":"bash ~/scripts/secrets.sh lock"}'
# --- other tools, and an empty or missing list
want allow Write '{"file_path":"'"$H"'/.config/msm/secrets/api.key"}'
printf '## Secrets\n\nnever_read:\n\nnothing: here\n' > "$TMP/empty.md"
SECRETS_GUARD_CONF="$TMP/empty.md" want allow Read '{"file_path":"'"$H"'/.config/msm/secrets/api.key"}'
SECRETS_GUARD_CONF="$TMP/none.md" want allow Read '{"file_path":"'"$H"'/.config/msm/secrets/api.key"}'
# --- end to end: the opt-in marker and the real overlay in a temp repo
unset SECRETS_GUARD_CONF SECRETS_GUARD_HOME
R="$TMP/repo"; mkdir -p "$R/docs/orchestration"; git -C "$R" init -q 2>/dev/null
printf 'team:\n  seat: Orca\n\n## Secrets\n\nnever_read:\n  - %s/.config/msm/secrets/\n' "$H" > "$R/docs/orchestration/ORCHESTRATION.md"
want allow Read '{"file_path":"'"$H"'/.config/msm/secrets/api.key"}' "$R"
touch "$R/docs/orchestration/.kit-hooks"
want deny  Read '{"file_path":"'"$H"'/.config/msm/secrets/api.key"}' "$R"
want allow Read '{"file_path":"'"$H"'/proj/src/a.ts"}' "$R"
out="$(printf '{"cwd":"%s","tool_name":"Read","tool_input":{"file_path":"%s/.config/msm/secrets/api.key"}}' "$R" "$H" | bash "$HOOK")"
case "$out" in *"never_read"*"ask the human"*) pass=$((pass+1)) ;; *) fail=$((fail+1)); echo "FAIL reason text: $out" ;; esac
# a linked worktree follows the main checkout's list
git -C "$R" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init 2>/dev/null; git -C "$R" worktree add -q "$TMP/wt" -b wt 2>/dev/null
want deny  Read '{"file_path":"'"$H"'/.config/msm/secrets/api.key"}' "$TMP/wt"
echo "secrets-guard: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
