#!/usr/bin/env bash
# PreToolUse hook (orchestration-kit) for Read|Grep and Bash: OPTIONAL secrets guard. A session never reads a
# key store: the paths the project lists under `never_read:` in docs/orchestration/ORCHESTRATION.md are refused
# for the Read tool, for Grep (a search inside one, or one that would sweep through one), and for a Bash command
# whose text names one (cat, less, gpg, cp ... anything). A key a session needs is the human's job to supply.
#
# NO-OP (exit 0, no output) unless ALL hold:
#   - the session's repo carries the opt-in marker docs/orchestration/.kit-hooks;
#   - docs/orchestration/ORCHESTRATION.md has a `never_read:` block with at least one `- <path>` line below it
#     (the list is the switch: no list, no guard). `~` means the home directory; a directory covers everything
#     beneath it; an entry with `*` is a shell pattern matched against the whole path (e.g. `- *.pem`).
# Both are read from the MAIN checkout (first `git worktree list` entry), so linked worktrees follow it.
# It is a speed bump for an agent, not a sandbox: a path reached through a variable, a symlink or a script is
# not seen. Deliberately no set -e: a hook must never break a tool call. Dependencies: bash, git, grep, sed.
#
# Test mode: SECRETS_GUARD_CONF=<file> and SECRETS_GUARD_HOME=<dir> skip the repo lookup and use that list.

input="$(cat 2>/dev/null || true)"
[ -n "$input" ] || exit 0

json_str() {  # first value of a top-level-looking string key (JSON escapes inner quotes as \")
  printf '%s' "$input" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" 2>/dev/null | head -n1 \
    | sed -e 's/^[^:]*:[[:space:]]*"//' -e 's/"$//' -e 's#\\/#/#g'
}
tool="$(json_str tool_name)"
case "$tool" in Read|Grep|Bash) ;; *) exit 0 ;; esac

home="${SECRETS_GUARD_HOME:-$HOME}"
if [ -n "${SECRETS_GUARD_CONF:-}" ]; then
  conf="$SECRETS_GUARD_CONF"
else
  cwd="$(json_str cwd)"; [ -n "$cwd" ] && [ -d "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
  [ -d "$cwd" ] || exit 0
  main="$(git -C "$cwd" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
  [ -n "$main" ] && [ -d "$main" ] || exit 0
  [ -f "$main/docs/orchestration/.kit-hooks" ] || exit 0
  conf="$main/docs/orchestration/ORCHESTRATION.md"
fi
[ -f "$conf" ] || exit 0
# The entries: the `- ` lines right after `never_read:` (blank lines and comments between them are fine).
entries="$(awk '
  /^[[:space:]]*never_read:[[:space:]]*(#.*)?$/ { on = 1; next }
  on && /^[[:space:]]*-[[:space:]]+/ { sub(/^[[:space:]]*-[[:space:]]+/, ""); sub(/[[:space:]]+#.*$/, ""); sub(/[[:space:]]+$/, ""); gsub(/^`|`$/, ""); if ($0 != "") print; next }
  on && /^[[:space:]]*(#.*)?$/ { next }
  on { on = 0 }
' "$conf" 2>/dev/null)"
[ -n "$entries" ] || exit 0

expand() {  # ~ and $HOME -> the home directory; trailing / dropped
  local p="$1"
  case "$p" in "~") p="$home" ;; "~/"*) p="$home/${p#\~/}" ;; '$HOME') p="$home" ;; '$HOME/'*) p="$home/${p#\$HOME/}" ;; esac
  printf '%s' "${p%/}"
}
hit=""
guarded() {  # <absolute path>: is it inside, equal to, or (for a sweep) above a listed entry?
  local p="$1" e x sweep="${2:-0}"
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    x="$(expand "$e")"
    case "$x" in
      *\**) case "$p" in $x) hit="$e"; return 0 ;; esac ;;
      *) case "$p" in "$x"|"$x"/*) hit="$e"; return 0 ;; esac
         [ "$sweep" = 1 ] && case "$x" in "$p"/*) hit="$e"; return 0 ;; esac ;;
    esac
  done <<<"$entries"
  return 1
}
absolute() {  # relative -> against the session cwd; symlinks are not followed (a speed bump)
  local p="$1" c
  case "$p" in "~"|"~/"*|'$HOME'|'$HOME/'*) p="$(expand "$p")" ;; esac
  if [ "${p#/}" = "$p" ]; then c="$(json_str cwd)"; [ -n "$c" ] || c="${CLAUDE_PROJECT_DIR:-$PWD}"; p="$c/$p"; fi
  printf '%s' "$p"
}

what=""
case "$tool" in
  Read)
    path="$(json_str file_path)"; [ -n "$path" ] || exit 0
    guarded "$(absolute "$path")" && what="reading $path" ;;
  Grep)
    path="$(json_str path)"; [ -n "$path" ] || path="."
    guarded "$(absolute "$path")" 1 && what="searching $path" ;;
  Bash)
    body="$(printf '%s' "$input" | sed 's#\\/#/#g')"
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      x="$(expand "$e")"; case "$x" in *\**) continue ;; esac   # patterns are checked on real paths only
      for form in "$x" "~/${x#"$home"/}" "\$HOME/${x#"$home"/}"; do
        case "$form" in "~/$x"|"\$HOME/$x") continue ;; esac     # x was not under home: skip the made-up forms
        case "$body" in *"$form"*) hit="$e"; what="a command naming $form"; break 2 ;; esac
      done
    done <<<"$entries" ;;
esac
[ -n "$what" ] || exit 0

reason="Blocked by orchestration-kit secrets guard: $what. That path is listed under never_read in docs/orchestration/ORCHESTRATION.md: sessions never read key stores. If the work needs a key, stop and ask the human (through the seat under a banner); it is theirs to supply. The human can remove the entry to allow it."
reason="$(printf '%s' "$reason" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
exit 0
