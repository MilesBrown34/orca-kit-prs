#!/usr/bin/env bash
# docs/LESSONS.md keeps the shape the lessons-clean skill relies on: exactly one "## Submitted" heading and it
# is the last H2; a "Last clean: YYYY-MM-DD" line under it with a real date; every entry under it is a "- " line;
# the numbered lessons above are unique and ascending. Then proves each check can fail on a planted copy.
#   bash tests/lessons-clean.test.sh
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
ok() { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $*"; }

check_file() {  # <file> -> prints one line per problem, nothing when clean
  local f="$1" subs last
  subs="$(grep -c '^## Submitted' "$f")"
  [ "$subs" -eq 1 ] || echo "expected one '## Submitted' heading, found $subs"
  [ "$(grep '^## ' "$f" | tail -1)" = "$(grep '^## Submitted' "$f" | head -1)" ] || echo "'## Submitted' is not the last section"
  last="$(sed -n 's/^Last clean:[[:space:]]*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)[[:space:]]*$/\1/p' "$f" | head -1)"
  [ -n "$last" ] || echo "no 'Last clean: YYYY-MM-DD' line"
  [ -z "$last" ] || date -d "$last" >/dev/null 2>&1 || echo "'Last clean: $last' is not a date"
  sed -n '/^## Submitted/,$p' "$f" | grep -E '^[0-9]+\. ' >/dev/null && echo "a numbered lesson sits under '## Submitted'"
  awk '/^## Submitted/{s=1;next} s&&/^Last clean:/{p=1;next} s&&p==1&&/^$/{p=2;next} s&&p==2&&!/^$/{p=3} s&&p==3&&/^$/{p=4;next} s&&p==4&&!/^$/&&!/^- /{print "a Submitted entry does not start with \x27- \x27: " $0; exit}' "$f"
  sed -n '1,/^## Submitted/p' "$f" | grep -oE '^[0-9]+\. ' | tr -d '. ' | awk 'NR>1 && $1<=prev {print "lesson numbers not ascending/unique at " $1; exit} {prev=$1}'
}

L="$ROOT/docs/LESSONS.md"
out="$(check_file "$L")"
[ -z "$out" ] && ok || bad "docs/LESSONS.md: $out"
[ -f "$ROOT/skills/lessons-clean/SKILL.md" ] && ok || bad "skills/lessons-clean/SKILL.md missing"

# the checks can fail: plant one defect per check in a copy
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
plant() {  # <label> <sed script> -> the planted copy must be refused
  local c="$T/l.md"; sed "$2" "$L" > "$c"
  [ -n "$(check_file "$c")" ] && ok || bad "planted '$1' was not caught"
}
plant "second Submitted heading"  '1a ## Submitted twice'
plant "bad date"                  's/^Last clean: .*/Last clean: 2026-13-40/'
plant "no date line"              '/^Last clean:/d'
plant "duplicate number"          '0,/^2\. /s//1. /'
plant "numbered under Submitted"  '$a 999. **A lesson in the inbox.**'
plant "entry not a dash line"     '$a a loose line'
printf '%s\n' "$T/l.md" >/dev/null
echo "lessons-clean: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
