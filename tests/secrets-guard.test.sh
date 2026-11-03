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
# --- allow_read: one listed file passes; everything else under never_read stays refused
S="$H/.config/msm/secrets"; mkdir -p "$S/dir.d"; echo k > "$S/service-api-key"; echo k > "$S/dir.d/inner.key"
ln -s "$S/api.key" "$S/link-key"
CONF2="$TMP/ORCH2.md"
cat > "$CONF2" <<EOC
## Secrets

never_read:
  - ~/.config/msm/secrets/
  - *.pem

allow_read:
  - ~/.config/msm/secrets/service-api-key   # one file, by its exact path
  - ~/.config/msm/secrets/dir.d             # a directory: ignored
  - ~/.config/msm/secrets/*.key             # a pattern: ignored
  - ~/.config/msm/secrets/link-key          # a symlink: ignored (it would let another file through)
  - ~/.config/msm/secrets/x/../api.key      # a path trick: ignored
  - ~/.config/msm/secrets//api.key          # a path trick: ignored
  - ~/.config/msm/secrets/./api.key         # a path trick: ignored
  - ~/.config/msm/secrets/nope/..           # a path trick: ignored
  - ~/.config/msm/secrets/api.ke?           # a pattern: ignored
  - ~/.config/msm/secrets/api.ke[y]         # a pattern: ignored
  - .config/msm/secrets/api.key             # not an absolute path: ignored
EOC
export SECRETS_GUARD_CONF="$CONF2" SECRETS_GUARD_HOME="$H"
# the allowed file: Read, a Grep of that one file, a Bash command naming it (every spelling, quoted or not)
want allow Read '{"file_path":"'"$S"'/service-api-key"}'
want allow Read '{"file_path":"~/.config/msm/secrets/service-api-key"}'
want allow Read '{"file_path":"service-api-key"}' "$S"
want allow Grep '{"pattern":"KEY","path":"'"$S"'/service-api-key"}'
want allow Bash '{"command":"cat ~/.config/msm/secrets/service-api-key"}'
want allow Bash '{"command":"curl -H @$HOME/.config/msm/secrets/service-api-key https://x"}'
want allow Bash '{"command":"cat \"~/.config/msm/secrets/service-api-key\" | wc -c"}'
want allow Bash '{"command":"cat ~/.config/msm/secrets/service-api-key; echo done"}'
# a key file handed to a tool by an env prefix (each spelling), an option, a quoted word
A='~/.config/msm/secrets/service-api-key'; AH='$HOME/.config/msm/secrets/service-api-key'; AA="$S/service-api-key"
for k in "$A" "$AH" "$AA"; do
  want allow Bash '{"command":"GLS_KEY_FILE='"$k"' bash tools/glstest/run.sh --dry"}'
done
want allow Bash '{"command":"export KEY_FILE='"$A"'; bash tools/x/run.sh"}'
want allow Bash '{"command":"tool --key-file='"$A"' run"}'
want allow Bash '{"command":"cat '"'$AA'"' && echo ok"}'
want allow Bash '{"command":"cp '"$A"' /tmp/k\nwc -c /tmp/k"}'
want allow Bash '{"command":"echo ok","description":"reads '"$A"'.bak"}'
# named any other way than a plain word: refused (it could become another path)
want deny  Bash '{"command":"KEY=$(cat '"$AA"') python3 run.py"}'
for k in "$A" "$AH" "$AA"; do
  want deny  Bash '{"command":"cat '"$k"''"'"'.bak'"'"'"}'
  want deny  Bash '{"command":"ls $(dirname '"$k"')"}'
done
want deny  Bash '{"command":"cat '"$A"'\".bak\""}'
want deny  Bash '{"command":"cat '"$A"'`echo .bak`"}'
want deny  Bash '{"command":"cat '"$A"''"'"''"'"'*"}'
want deny  Bash '{"command":"cat \"'"$A"'\"*"}'
want deny  Bash '{"command":"cat \"'"$A"'\".bak"}'
want deny  Bash '{"command":"cat $(dirname '"$A"')/api.key"}'
want deny  Bash '{"command":"cd \"$(dirname '"$A"')\" && cat api.key"}'
want deny  Bash '{"command":"ls `dirname '"$A"'`"}'
want deny  Bash '{"command":"f='"$A"'; cat ${f%/*}/api.key"}'
want deny  Bash '{"command":"f='"$A"'; cat ${f/service-api-key/api.key}"}'
want deny  Bash '{"command":"find $(dirname '"$A"') -type f -exec cat {} +"}'
want deny  Bash '{"command":"echo '"$A"' | xargs dirname | xargs ls"}'
want deny  Bash '{"command":"cat <<< '"$A"'"}'
want deny  Bash '{"command":"cat <(cat '"$A"')"}'
want deny  Bash '{"command":"realpath '"$A"'"}'
want deny  Bash '{"command":"readlink -f '"$A"'"}'
want deny  Bash '{"command":"basename '"$A"'"}'
want deny  Bash '{"command":"eval cat '"$A"'"}'
want deny  Bash '{"command":"ls '"$A"'/.."}'
want deny  Bash '{"command":"cat {'"$A"',x}"}'
want deny  Bash '{"command":"(cat '"$A"')"}'
want deny  Bash '{"command":"f='"$A"'; cat $f.bak"}'
want deny  Bash '{"command":"export F='"$A"'; cat \"$F\"'"'"'.bak'"'"'"}'
want deny  Bash '{"command":"F+='"$A"'; cat $F*"}'
want deny  Bash '{"command":"echo '"$A"' | sed s/service-api-key/api.key/ | while read f; do cat $f; done"}'
want deny  Bash '{"command":"echo '"$A"' | sed s/^/cat\\ / | bash"}'
want deny  Bash '{"command":"printf %s '"$A"' > /tmp/p"}'
want deny  Bash '{"command":"mapfile -t a <<< '"$A"'"}'
want deny  Bash '{"command":"bash -c '"'"'cat '"$A"''"'"'.bak"}'
# caught by one rule each (the falsify record names them)
want deny  Bash '{"command":"cat $(ls '"$A"' ).bak"}'
want deny  Bash '{"command":"cat `ls '"$A"' `.bak"}'
want deny  Bash '{"command":"cat <(ls '"$A"' )"}'
want deny  Bash '{"command":"ls '"$A"' | sed s/^/cat\\ / | bash"}'
want deny  Bash '{"command":"ls '"$A"' | python3"}'
want deny  Bash '{"command":"cat $\u0028ls '"$A"' \u0029.bak"}'   # a JSON \u escape counts as a marker
# the refusal says how to name it
out="$(printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"cat '"$A"'.bak"}}' "$H/proj" | bash "$HOOK")"
case "$out" in *"plain word"*"name it alone"*) pass=$((pass+1)) ;; *) fail=$((fail+1)); echo "FAIL the misuse refusal lost its how-to" ;; esac
# a sibling, the folder, a glob, the allowed path plus more
want deny  Read '{"file_path":"'"$S"'/api.key"}'
want deny  Grep '{"pattern":"KEY","path":"'"$S"'"}'
want deny  Grep '{"pattern":"KEY","path":"'"$H"'/.config"}'
want deny  Bash '{"command":"cat ~/.config/msm/secrets/api.key"}'
want deny  Bash '{"command":"ls ~/.config/msm/secrets"}'
want deny  Bash '{"command":"cat ~/.config/msm/secrets/*"}'
want deny  Bash '{"command":"cat ~/.config/msm/secrets/service-api-key*"}'
want deny  Bash '{"command":"cat ~/.config/msm/secrets/service-api-key.bak"}'
want deny  Bash '{"command":"cat ~/.config/msm/secrets/service-api-key ~/.config/msm/secrets/api.key"}'
want deny  Bash '{"command":"cat ~/.config/msm/secrets/service-api-key && cd ~/.config/msm/secrets && cat api.key"}'
want deny  Bash '{"command":"cat ~/.config/msm/secrets/service-api-key\\ x"}'
# ../ and // tricks: never the allowed file's pass
want deny  Read '{"file_path":"'"$S"'/service-api-key/../api.key"}'
want deny  Read '{"file_path":"'"$S"'//service-api-key"}'
want deny  Read '{"file_path":"'"$S"'/./service-api-key"}'
want deny  Bash '{"command":"cat ~/.config/msm/secrets/service-api-key/../api.key"}'
want deny  Bash '{"command":"cat ~/.config/msm/secrets//service-api-key"}'
# ignored allow entries: a directory, a pattern, a symlink, a path trick
want deny  Read '{"file_path":"'"$S"'/dir.d"}'
want deny  Grep '{"pattern":"KEY","path":"'"$S"'/dir.d"}'
want deny  Bash '{"command":"ls ~/.config/msm/secrets/dir.d"}'
want deny  Bash '{"command":"cat ~/.config/msm/secrets/*.key"}'
want deny  Read '{"file_path":"'"$S"'/link-key"}'
want deny  Bash '{"command":"cat ~/.config/msm/secrets/link-key"}'
want deny  Read '{"file_path":"'"$S"'/x/../api.key"}'
want deny  Bash '{"command":"cat ~/.config/msm/secrets/x/../api.key"}'
want deny  Bash '{"command":"cat ~/.config/msm//secrets/api.key | head; ls ~/.config/msm/secrets"}'
want deny  Read '{"file_path":"'"$S"'/./api.key"}'
want deny  Read '{"file_path":"'"$S"'//api.key"}'
want deny  Bash '{"command":"ls ~/.config/msm/secrets/nope/.."}'
want deny  Bash '{"command":"cat ~/.config/msm/secrets/api.ke?"}'
want deny  Bash '{"command":"cat ~/.config/msm/secrets/api.ke[y]"}'
# the allow list never opens a path the never_read list does not cover, and does not widen a pattern entry
want deny  Read '{"file_path":"'"$H"'/proj/cert.pem"}'
want allow Read '{"file_path":"'"$H"'/proj/src/a.ts"}'
# the header keeps its symlink note (a path reached through a symlink is not seen)
grep -q 'symlink' <(sed -n '1,30p' "$HOOK") && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL header lost its symlink note"; }
# an allow_read list with no never_read list: no guard at all, as before
printf '## Secrets\n\nallow_read:\n  - ~/.config/msm/secrets/service-api-key\n' > "$TMP/allowonly.md"
SECRETS_GUARD_CONF="$TMP/allowonly.md" want allow Read '{"file_path":"'"$S"'/api.key"}'
echo "secrets-guard: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
