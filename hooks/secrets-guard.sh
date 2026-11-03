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
# Optional `allow_read:` block (same format): one FILE by its exact path (`~` = home) is let through although a
# never_read entry covers it, until the human removes the line: a Read of exactly that path, a Grep of that one
# file, and a Bash command that names it as a plain word: a space, tab, newline, = or @ (or the start) before it,
# a space, tab, newline, ; | & < > (or the end) after it, or the same around it in matching quotes ("K" or 'K').
# So `cat K`, `KEY_FILE=K bash run.sh` and `curl -d @K` pass. Named any other way the command is refused: more
# after it (K.bak, K'.bak', K''*, K/..), or a command that could turn its text into another path: $( ), backticks,
# ${ }, <<, <( ), >( ), eval, xargs, dirname, basename, realpath, readlink, read, mapfile, an echo or printf of
# it, a pipe into a shell or script interpreter, or a variable it is assigned to expanded later ($VAR).
# Anything else under never_read stays refused: the folder, a sibling, a glob, a `..`, `.` or `//` spelling.
# An allow entry that is a directory, a symlink, a pattern (* ? [) or not a plain absolute path is ignored.
# It is a speed bump for an agent, not a sandbox: a path reached through a variable, a symlink or a script is
# not seen, nor what a program does with the allowed path it is given (a script that derives the folder from
# it, a file the command writes and a later command runs). Deliberately no set -e: a hook must never break a
# tool call. Dependencies: bash, git, grep, sed, awk, sort.
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
block() { awk -v key="$1" '
  $0 ~ "^[[:space:]]*" key ":[[:space:]]*(#.*)?$" { on = 1; next }
  on && /^[[:space:]]*-[[:space:]]+/ { sub(/^[[:space:]]*-[[:space:]]+/, ""); sub(/[[:space:]]+#.*$/, ""); sub(/[[:space:]]+$/, ""); gsub(/^`|`$/, ""); if ($0 != "") print; next }
  on && /^[[:space:]]*(#.*)?$/ { next }
  on { on = 0 }
' "$conf" 2>/dev/null; }
entries="$(block never_read)"
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

# The allowed files: plain absolute file paths only (no pattern, no . / .. / // spelling, no directory, no symlink).
allowed=""
while IFS= read -r e; do
  [ -n "$e" ] || continue
  x="$(expand "$e")"
  case "$x" in /*) ;; *) continue ;; esac
  case "$x" in *[\*\?\[]*|*//*|*/./*|*/../*|*/..) continue ;; esac
  [ -d "$x" ] || [ -L "$x" ] && continue
  allowed="$allowed$x"$'\n'
done <<<"$(block allow_read)"
is_allowed() { [ -n "$allowed" ] && [ -n "$1" ] && printf '%s' "$allowed" | grep -qxF -- "$1"; }

json_cmd() {  # <cmd|rest>: tool_input.command with its JSON escapes decoded (cmd), or the input without that value
  printf '%s' "$input" | awk -v want="$1" 'BEGIN { RS = "\001" } { s = s $0 } END {
    k = index(s, "\"command\""); i = k + 9; n = length(s)
    while (k && i <= n && substr(s, i, 1) ~ /[ \t\r\n:]/) i++
    if (!k || substr(s, i, 1) != "\"") { if (want == "rest") printf "%s", s; exit }
    st = i; i++; out = ""
    while (i <= n) {
      c = substr(s, i, 1)
      if (c == "\"") break
      if (c == "\\") {
        e = substr(s, i + 1, 1); i += 2
        if (e == "n") c = "\n"; else if (e == "t") c = "\t"; else if (e == "r") c = "\r"
        else if (e == "b" || e == "f") c = " "; else if (e == "u") c = "`"; else c = e   # \uXXXX: a marker, never a plain word
      } else i++
      out = out c
    }
    if (want == "cmd") printf "%s", out; else printf "%s", substr(s, 1, st - 1) substr(s, i + 1)
  }'
}
plain_before() { case "$1" in ""|" "|$'\t'|$'\n'|=|@) return 0 ;; esac; return 1; }
plain_after() { case "$1" in ""|" "|$'\t'|$'\n'|";"|"|"|"&"|"<"|">") return 0 ;; esac; return 1; }
# Bash with an allow list: an allowed file named as a plain word (see the header) is blanked out of the command
# and the rest is checked as before; an allowed file under never_read named any other way refuses the command.
allow_bash() {
  local cmd rest list len x form p r head b bb a aa q pre name seg w re bad marker=0 nl=$'\n'
  local sep='[[:space:];|&(){}`"'"'"']'
  cmd="$(json_cmd cmd)"; rest="$(json_cmd rest | sed 's#\\/#/#g')"
  list="$(while IFS= read -r x; do
      [ -n "$x" ] || continue
      for form in "$x" "~/${x#"$home"/}" "\$HOME/${x#"$home"/}"; do
        case "$form" in "~/$x"|"\$HOME/$x") continue ;; esac
        case "$cmd$nl$rest" in *"$form"*) printf '%s\t%s\t%s\n' "${#form}" "$x" "$form" ;; esac
      done
    done <<<"$allowed" | sort -rn)"   # longest first: an allowed name that starts another is checked after it
  [ -n "$list" ] || return 0
  # Anything that could turn the name's text into another path.
  case "$cmd" in *'$('*|*'`'*|*'${'*|*'<<'*|*'<('*|*'>('*) marker=1 ;; esac
  re="(^|$sep)(eval|xargs|dirname|basename|realpath|readlink|read|mapfile|readarray)(\$|$sep|[<>])"
  [[ $cmd =~ $re ]] && marker=1
  re='\|[[:space:]]*((sudo|env|command|exec|nohup)[[:space:]]+)*([a-z]*sh|python[0-9.]*|perl|ruby|node|php|source|\.)($|[[:space:];|&)])'
  [[ $cmd =~ $re ]] && marker=1
  while IFS=$'\t' read -r len x form; do
    [ -n "$form" ] || continue
    p=""; r="$cmd"
    while case "$r" in *"$form"*) true ;; *) false ;; esac; do
      head="${r%%"$form"*}"; r="${r#*"$form"}"; p="$p$head"
      b="${p: -1}"; bb=""; [ "${#p}" -ge 2 ] && bb="${p: -2:1}"; a="${r:0:1}"; aa="${r:1:1}"
      bad=1; q=""
      if plain_before "$b" && plain_after "$a"; then bad=0; q="$b"; pre="${p%?}"
      elif { [ "$b" = '"' ] || [ "$b" = "'" ]; } && [ "$a" = "$b" ] && plain_before "$bb" && plain_after "$aa"; then
        bad=0; q="$bb"; pre="${p%??}"
      fi
      if [ "$bad" = 0 ] && [ "$q" = "=" ]; then   # NAME=<allowed>: $NAME must not be expanded in the command
        pre="${pre%+}"
        re='(^|[[:space:];|&(])([A-Za-z_][A-Za-z0-9_]*)$'
        if [[ $pre =~ $re ]]; then
          name="${BASH_REMATCH[2]}"; re='\$'"$name"'([^A-Za-z0-9_]|$)'
          [[ $cmd =~ $re ]] && bad=1
        fi
      fi
      seg="${p##*[;|&(\`\{$nl]}"; seg="${seg#"${seg%%[![:space:]]*}"}"   # its simple command: never echo / printf
      re='^[A-Za-z_][A-Za-z0-9_]*[+]?=[^[:space:]]*[[:space:]]+(.*)$'
      while [[ $seg =~ $re ]]; do seg="${BASH_REMATCH[1]}"; done
      w="${seg%%[[:space:]]*}"
      case "$w" in echo|printf|print) bad=1 ;; esac
      [ "$marker" = 1 ] && bad=1
      if [ "$bad" = 1 ]; then
        guarded "$x" || { p="$p$form"; continue; }
        what="a command using the allowed file $form other than as a plain word (name it alone: cat <file>, KEY_FILE=<file> tool, curl -d @<file>; never with more after it, inside \$( ), backticks or \${ }, or through echo, xargs, dirname, eval, read or a pipe into a shell)"
        return 0
      fi
      p="$p<allowed file>"
    done
    cmd="$p$r"
    rest="${rest//"$form"/<allowed file>}"
  done <<<"$list"
  body="$cmd$nl$rest"
}

what=""
case "$tool" in
  Read)
    path="$(json_str file_path)"; [ -n "$path" ] || exit 0
    is_allowed "$(absolute "$path")" && exit 0
    guarded "$(absolute "$path")" && what="reading $path" ;;
  Grep)
    path="$(json_str path)"; [ -n "$path" ] || path="."
    is_allowed "$(absolute "$path")" && exit 0
    guarded "$(absolute "$path")" 1 && what="searching $path" ;;
  Bash)
    body="$(printf '%s' "$input" | sed 's#\\/#/#g')"
    [ -n "$allowed" ] && allow_bash
    [ -z "$what" ] && while IFS= read -r e; do
      [ -n "$e" ] || continue
      x="$(expand "$e")"; case "$x" in *\**) continue ;; esac   # patterns are checked on real paths only
      for form in "$x" "~/${x#"$home"/}" "\$HOME/${x#"$home"/}"; do
        case "$form" in "~/$x"|"\$HOME/$x") continue ;; esac     # x was not under home: skip the made-up forms
        case "$body" in *"$form"*) hit="$e"; what="a command naming $form"; break 2 ;; esac
      done
    done <<<"$entries" ;;
esac
[ -n "$what" ] || exit 0

reason="Blocked by orchestration-kit secrets guard: $what. That path is listed under never_read in docs/orchestration/ORCHESTRATION.md: sessions never read key stores. If the work needs a key, stop and ask the human (through the seat under a banner); it is theirs to supply. The human can remove the entry, or let one file through by its exact path under allow_read."
reason="$(printf '%s' "$reason" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
exit 0
