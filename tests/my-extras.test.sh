#!/usr/bin/env bash
# Tests for my-extras/my-extras, my-extras/pr-check and my-extras/push-check (branch prs only; never sent upstream).
# Sandboxed: a fake "his kit" repo and a fake kit folder; no network, no gh.
# Also checks the REAL kit folder: prs may hold no change that belongs to no extra.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; X="$ROOT/my-extras/my-extras"; PC="$ROOT/my-extras/pr-check"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
has() { case "$3" in *"$2"*) pass=$((pass+1)) ;; *) fail=$((fail+1)); echo "FAIL $1: want '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) fail=$((fail+1)); echo "FAIL $1: did not want '$2' in: $3" ;; *) pass=$((pass+1)) ;; esac; }
rc_is() { [ "$2" = "$3" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL $1: want exit $2, got $3"; }; }
q() { git -C "$K" -c user.name=t -c user.email=t@t "$@" >/dev/null 2>&1; }
H="$TMP/his"; K="$TMP/kit"
export MY_EXTRAS_REPO="$K" MY_EXTRAS_NO_NET=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export MY_EXTRAS_WORDS="$TMP/words"; printf '# test list\nzebrafinch\n' >"$MY_EXTRAS_WORDS"
ver() { mkdir -p "$1/.claude-plugin"; printf '{ "name": "k", "version": "%s" }\n' "$2" > "$1/.claude-plugin/plugin.json"; }

# his kit: 1.0 with a launcher and a hud file
mkdir -p "$H/scripts"; git -C "$H" init -q -b main; ver "$H" 1.0
echo launcher > "$H/scripts/launch.sh"; echo hud > "$H/hud.ts"; printf '# Changelog\n\n## 1.0\n' > "$H/CHANGELOG.md"
git -C "$H" add -A; git -C "$H" commit -qm "1.0"
git clone -q "$H" "$K"; q remote rename origin upstream
# two extras from his kit, merged into prs; the tool's own folder committed on prs
q checkout -b extra/tabs upstream/main; echo "tab colors" >> "$K/scripts/launch.sh"; q commit -am "tabs"
q checkout -b extra/dots upstream/main; echo "dots" >> "$K/hud.ts"; q commit -am "dots"
q checkout -b prs upstream/main; q merge --no-ff extra/tabs -m "merge tabs"; q merge --no-ff extra/dots -m "merge dots"
mkdir -p "$K/my-extras"; echo tool > "$K/my-extras/x"; q add my-extras/x; q commit -m "tracking"
cat > "$K/MY-EXTRAS.md" <<'EOF'
## Details
### tabs
- name: Tabs
- status: Only mine
- pr:
- what: tab colors
### dots
- name: Dots
- status: Sent
- pr: 7
- what: project dots
- merge notes: keep the old key row
## Given to his kit
EOF

# --- header, check, files
out="$("$X" header)"; has "header: version and extras" "Orca-kit 1.0 + 2 extras" "$out"; hasnt "header: nothing new" "▲" "$out"; has "header: current shown green" "$(printf '\033[32mcurrent 1.0 ✓')" "$out"; hasnt "header: nothing unlisted" "⚠" "$out"
out="$("$X" check)"; rc_is "check: clean prs passes" 0 $?
has "files: from the branch" "scripts/launch.sh" "$("$X" files tabs)"
out="$("$X" refresh)"; has "page: table row" "| Tabs | tab colors | Only mine | — |" "$(cat "$K/MY-EXTRAS.md")"
has "page: PR number shown" "| Dots | project dots | Sent | #7 |" "$(cat "$K/MY-EXTRAS.md")"
has "page: details kept" "### dots" "$(cat "$K/MY-EXTRAS.md")"; has "page: merge notes kept" "- merge notes: keep the old key row" "$(cat "$K/MY-EXTRAS.md")"; has "page: files from git" "files (from git): hud.ts" "$(cat "$K/MY-EXTRAS.md")"
out="$("$X" header)"; has "header: refresh keeps the extras" "+ 2 extras" "$out"
sed -i 's/^- status: Only mine$/- status: Building/' "$K/MY-EXTRAS.md"
out="$("$X" header)"; has "header: an extra still being built is not counted" "+ 1 extra" "$out"
sed -i 's/^- status: Building$/- status: Only mine/' "$K/MY-EXTRAS.md"

# --- a stray edit straight on prs is caught; a tracking-only commit is not
echo "stray" >> "$K/hud.ts"; q commit -am "quick fix on prs"
out="$("$X" header)"; has "header: unlisted change flagged" "⚠ 1 unlisted change" "$out"
out="$("$X" check)"; rc=$?; rc_is "check: stray commit fails" 1 $rc; has "check: names it" "quick fix on prs" "$out"
q reset --hard HEAD~1
echo more > "$K/my-extras/x"; q commit -am "tracking 2"
out="$("$X" check)"; rc_is "check: tracking-only commit is fine" 0 $?

# --- his new release: marker, news, refit only for the extra whose files he changed
ver "$H" 1.1; echo "his launcher change" >> "$H/scripts/launch.sh"; printf '# Changelog\n\n## 1.1\n- **New: faster launch.**\n\n## 1.0\n' > "$H/CHANGELOG.md"
git -C "$H" commit -qam "1.1"; q fetch -q upstream
out="$("$X" header)"; has "header: newer version marked" "▲ current 1.1 (news)" "$out"; hasnt "header: not green when behind" "✓" "$out"; has "header: still on 1.0" "Orca-kit 1.0" "$out"
has "header: update in yellow" "$(printf '\033[1;33m▲')" "$out"; hasnt "header: NO_COLOR is plain" "$(printf '\033[')" "$(NO_COLOR=1 "$X" header)"
out="$("$X" news)"; has "news: versions" "His latest: 1.1" "$out"; has "news: changelog heading" "New: faster launch." "$out"
has "news: overlapping extra needs refit" "Tabs needs a refit (he changed scripts/launch.sh)" "$out"; has "news: other extra fine" "Dots: not affected" "$out"
out="$("$X" status)"; has "status: refit flag" "Only mine, needs refit" "$out"
"$X" refresh >/dev/null; has "page: refit in the table" "Only mine, needs refit" "$(cat "$K/MY-EXTRAS.md")"

# --- pr-check
out="$("$PC" dots)"; rc=$?; rc_is "pr-check: old base refused" 1 $rc; has "pr-check: says refit first" "refit it first" "$out"
q checkout -q extra/dots; q rebase -q upstream/main; q checkout -q prs
out="$("$PC" dots)"; rc_is "pr-check: refitted extra passes" 0 $?; has "pr-check: size line" "dots: 1 file, +1 -0 lines" "$out"
q checkout -q -b extra/leak upstream/main; echo "see the Zebrafinch seat" >> "$K/hud.ts"; q commit -am leak; q checkout -q prs
out="$("$PC" leak)"; rc_is "pr-check: personal name refused" 1 $?; has "pr-check: shows the line" "Zebrafinch" "$out"
q checkout -q -b extra/priv upstream/main; echo x > "$K/MY-EXTRAS.md.x"; mkdir -p "$K/my-extras"; echo y > "$K/my-extras/y"; q add my-extras/y; q commit -m priv; q checkout -q prs
out="$("$PC" priv)"; rc_is "pr-check: private file refused" 1 $?; has "pr-check: names it" "my-extras/y" "$out"
q checkout -q -b extra/both upstream/main; q merge --no-ff extra/dots -m "both"; q checkout -q prs
out="$("$PC" both)"; rc_is "pr-check: merge refused" 1 $?; has "pr-check: one extra at a time" "merge commit" "$out"
out="$("$PC" nope)"; rc_is "pr-check: unknown branch" 1 $?
out="$("$PC" 2>&1)"; rc_is "pr-check: usage" 64 $?
out="$(MY_EXTRAS_WORDS="$TMP/none" "$PC" dots)"; rc_is "pr-check: no word list refused" 1 $?; has "pr-check: says why" "no private word list" "$out"

# --- an extra amended after its merge is the same change, not a stray commit (matched by patch id)
q checkout -q extra/tabs; q commit -q --amend -m "tabs (reworded after the merge)"; q checkout -q prs
out="$("$X" check)"; rc_is "check: amended extra commit is not stray" 0 $?
out="$("$X" header)"; hasnt "header: amended extra not flagged" "⚠" "$out"

# --- push-check: tree and diff scans, the pre-push hook on a real push (to a bare fork), from a worktree too
PCK="$ROOT/my-extras/push-check"; R="$TMP/fork.git"; git init -q --bare "$R"; q remote add origin "$R"
cp "$PCK" "$K/my-extras/push-check"; q add my-extras/push-check; q commit -qm "tracking: push-check"   # the hook runs the main checkout's copy
q push -q origin prs
out="$("$PCK" tree prs)"; rc_is "push-check: clean tree passes" 0 $?
out="$("$PCK" tree extra/leak)"; rc_is "push-check: word in a file refused" 1 $?; has "push-check: file and line named" "hud.ts:" "$out"; has "push-check: says REFUSED" "REFUSED: 1 line" "$out"
out="$("$PCK" diff upstream/main extra/leak)"; rc_is "push-check: word in added lines refused" 1 $?
out="$("$PCK" diff upstream/main extra/dots)"; rc_is "push-check: clean diff passes" 0 $?
out="$(MY_EXTRAS_WORDS="$TMP/none" "$PCK" tree prs 2>&1)"; rc_is "push-check: no word list = 64" 64 $?; has "push-check: says no list" "no private word list" "$out"
out="$("$PCK" bogus 2>&1)"; rc_is "push-check: usage" 64 $?
out="$("$PCK" install)"; rc_is "push-check: install" 0 $?; has "push-check: hook path shown" "hooks/pre-push" "$out"
[ -x "$K/.git/hooks/pre-push" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL push-check: hook not executable"; }
q checkout -q -b work prs; echo fine >> "$K/hud.ts"; q commit -qam "a clean change"
out="$(git -C "$K" push origin work 2>&1)"; rc_is "hook: clean new branch pushes" 0 $?
echo "a zebrafinch landed" >> "$K/hud.ts"; q commit -qam "adds a word"
out="$(git -C "$K" push origin work 2>&1)"; rc_is "hook: word in a file blocks the push" 1 $?; has "hook: names the file" "hud.ts" "$out"; has "hook: says REFUSED" "REFUSED" "$out"
q reset -q --hard HEAD~1; q commit -q --allow-empty -m "mentions Zebrafinch in the message only"
out="$(git -C "$K" push origin work 2>&1)"; rc_is "hook: word in a commit message blocks the push" 1 $?; has "hook: shows the message" "in the message only" "$out"
q reset -q --hard HEAD~1
out="$(git -C "$K" push origin work 2>&1)"; rc_is "hook: clean again pushes" 0 $?
out="$(git -C "$K" push origin --delete work 2>&1)"; rc_is "hook: a branch delete is let through" 0 $?
q checkout -q -b bare-extra upstream/main; echo "zebrafinch on a branch without the tool" >> "$K/hud.ts"; q commit -qam "no tool here"
out="$(git -C "$K" push origin bare-extra 2>&1)"; rc_is "hook: blocks from a branch without my-extras (uses prs's copy)" 1 $?; has "hook: still names the file" "hud.ts" "$out"
q reset -q --hard HEAD~1; out="$(git -C "$K" push origin bare-extra 2>&1)"; rc_is "hook: clean branch without my-extras pushes" 0 $?
q checkout -q prs; q branch -q -D bare-extra; git -C "$K" push -q origin --delete bare-extra
git -C "$K" worktree add -q "$TMP/wt" -b wt-branch prs 2>/dev/null
echo "zebrafinch again" >> "$TMP/wt/hud.ts"; git -C "$TMP/wt" -c user.name=t -c user.email=t@t commit -qam "from a worktree"
out="$(git -C "$TMP/wt" push origin wt-branch 2>&1)"; rc_is "hook: blocks from a linked worktree too" 1 $?; has "hook: worktree push names the file" "hud.ts" "$out"
git -C "$K" worktree remove --force "$TMP/wt"; q branch -q -D wt-branch work
q checkout -q prs

# --- pr-check uses the same scanner
out="$("$PC" leak)"; rc_is "pr-check: still refuses a personal name" 1 $?; has "pr-check: shows the line through push-check" "Zebrafinch" "$out"

# --- the fork's own README blocks live on extra/fork-readme
q checkout -q -b extra/fork-readme "$(git -C "$K" merge-base prs upstream/main)"   # from the base prs is built on, like a real extra before an update
printf '# his kit\n<!-- own-fork:top -->\n(filled by release)\n<!-- /own-fork:top -->\n\nmiddle\n\n## PRS'"'"'s changelog\n\nArtekka'"'"'s own changelog is in CHANGELOG.md.\n\n<!-- own-fork:changelog -->\n<!-- /own-fork:changelog -->\n' > "$K/README.md"
q add README.md; q commit -qm "fork readme blocks"; q checkout -q prs; q merge -q --no-ff extra/fork-readme -m "merge fork-readme"
sed -i '/^## Given to his kit/i ### fork-readme\n- name: Fork README\n- status: Only mine\n- pr:\n- what: the top and end of the README are this fork'"'"'s own\n' "$K/MY-EXTRAS.md"
# --- release: refusals first, then a real one against the bare fork
export MY_EXTRAS_GATE=true
out="$("$X" release --dry-run 2>&1)"; rc_is "release: refused while his kit is newer" 1 $?; has "release: says update first" "new commit" "$out"
q merge -q -X ours upstream/main -m "update: his 1.1"      # prs now holds his newest kit (-X ours: both appended to launch.sh)
echo dirty >> "$K/hud.ts"
out="$("$X" release --dry-run 2>&1)"; rc_is "release: refused on a dirty tree" 1 $?; has "release: says uncommitted" "uncommitted" "$out"
q checkout -q -- hud.ts
echo stray2 >> "$K/hud.ts"; q commit -qam "stray on prs"
out="$("$X" release --dry-run 2>&1)"; rc_is "release: refused with an unlisted change" 1 $?; has "release: names it" "stray on prs" "$out"
q reset -q --hard HEAD~1
out="$("$X" release --dry-run 2>&1)"; rc_is "release: dry run passes the checks" 0 $?; has "release: plan shown" "tag prs" "$out"; has "release: first tag is v1.0.0" "v1.0.0" "$out"
has "release: notes name the kit and the extras" "Orca-kit v1.0.0: Artekka's orchestration kit 1.1 plus 2 extras" "$out"; has "release: notes list an extra" "**Tabs**: tab colors" "$out"; has "release: page step shown" "Release page" "$out"; has "release: README step shown" "rewrite README's top block" "$out"; has "release: first entry" "First official release: Artekka's 1.1 plus 2 extras" "$out"
hasnt "release: dry run leaves README alone" "v1.0.0" "$(git -C "$K" show prs:README.md)"
sed -i 's/^- what: tab colors$/- what: tab colors for zebrafinch/' "$K/MY-EXTRAS.md"
out="$("$X" release --dry-run 2>&1)"; rc_is "release: refused when the notes hold a private word" 1 $?; has "release: says notes" "release notes hold a private word" "$out"
sed -i 's/^- what: tab colors for zebrafinch$/- what: tab colors/' "$K/MY-EXTRAS.md"
out="$("$PCK" file "$K/MY-EXTRAS.md")"; rc_is "push-check: file mode on a clean file" 0 $?
printf 'a zebrafinch line\n' > "$TMP/note.md"; out="$("$PCK" file "$TMP/note.md")"; rc_is "push-check: file mode refuses" 1 $?; has "push-check: file mode names the line" "note.md:1:" "$out"
[ -z "$(git -C "$K" tag -l 'v1.*')" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL release: dry run made a tag"; }
out="$(MY_EXTRAS_GATE=false "$X" release 2>&1)"; rc_is "release: refused on a red gate" 1 $?; has "release: says red" "gate is red" "$out"
out="$("$X" release 2>&1)"; rc_is "release: succeeds" 0 $?; has "release: reports the tag" "released v1.0.0" "$out"; has "release: README written by the red-gate attempt, so already current" "already current on extra/fork-readme for v1.0.0" "$out"; has "release: page skipped offline" "skipped (no network)" "$out"
rd="$(git -C "$K" show prs:README.md)"; has "readme: top names the release" "official release is **v1.0.0**, on Artekka's 1.1" "$rd"; has "readme: extras table" "| Tabs | tab colors |" "$rd"; hasnt "readme: the readme extra is not listed" "| Fork README |" "$rd"; has "readme: changelog entry" "### v1.0.0 (" "$rd"; has "readme: middle kept" "middle" "$rd"
[ "$(git -C "$K" rev-parse extra/fork-readme:README.md)" = "$(git -C "$K" rev-parse prs:README.md)" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL readme: branch and prs differ"; }
out="$("$X" check)"; rc_is "check: readme commits belong to the extra" 0 $?
[ "$(git -C "$R" rev-parse extra/fork-readme)" = "$(git -C "$K" rev-parse extra/fork-readme)" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL release: readme extra branch not pushed to the fork"; }
[ "$(git -C "$R" rev-parse main)" = "$(git -C "$K" rev-parse prs)" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL release: fork main is not prs"; }
[ "$(git -C "$R" rev-parse v1.0.0^{commit})" = "$(git -C "$K" rev-parse prs)" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL release: tag not on the fork"; }
out="$("$X" news)"; has "news: official version shown" "Official version: v1.0.0." "$out"
echo more2 > "$K/my-extras/x"; q commit -qam "tracking 3"
out="$("$X" header)"; hasnt "header: carries no release flag" "⚑" "$out"
sed -i 's/^- status: Sent$/- status: Merged/' "$K/MY-EXTRAS.md"   # Dots went to his kit: the next entry says so
out="$("$X" release 2>&1)"; rc_is "release: second release overwrites main" 0 $?; has "release: patch bump by default" "released v1.0.1" "$out"
rd="$(git -C "$K" show prs:README.md)"; has "readme: second entry first" "### v1.0.1 (" "${rd%%### v1.0.0*}"; has "readme: entry says kit unchanged" "Artekka's kit still 1.1." "$rd"; has "readme: entry names the extra that left" "retired: Dots." "$rd"; hasnt "readme: table drops the merged extra" "| Dots |" "$rd"
[ "$(git -C "$R" rev-parse main)" = "$(git -C "$K" rev-parse prs)" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL release: fork main not moved by the second release"; }
out="$("$X" release 2>&1)"; rc_is "release: same commit twice refused" 1 $?; has "release: says already released" "already released as v1.0.1" "$out"
echo more3 > "$K/my-extras/x"; q commit -qam "tracking 4"
out="$("$X" release --minor 2>&1)"; rc_is "release: --minor" 0 $?; has "release: minor bump" "released v1.1.0" "$out"
echo more4 > "$K/my-extras/x"; q commit -qam "tracking 5"
out="$("$X" release --major --dry-run 2>&1)"; rc_is "release: --major dry run" 0 $?; has "release: major bump" "v2.0.0" "$out"
git -C "$K" tag -a v1.1.1 -m "his tag, not ours" prs
out="$("$X" release --dry-run 2>&1)"; rc_is "release: a foreign tag with the next name stops it" 1 $?; has "release: names the clash" "v1.1.1 already exists" "$out"
git -C "$K" tag -d v1.1.1 >/dev/null
unset MY_EXTRAS_GATE

# --- the real kit folder: prs holds nothing that belongs to no extra
if [ -f "$ROOT/MY-EXTRAS.md" ] && [ "$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)" = prs ]; then
  out="$(env -u MY_EXTRAS_REPO MY_EXTRAS_NO_NET=1 "$X" check)"; rc=$?
  rc_is "real kit: no unlisted change on prs ($out)" 0 $rc
fi

echo "my-extras: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
