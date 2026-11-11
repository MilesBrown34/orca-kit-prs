---
name: lessons-clean
description: Weekly clean of docs/LESSONS.md — fold the lines under "## Submitted" into numbered lessons in the file's own format (condensed once, never reworded later), merge submissions that share a problem, add genuinely new information to an existing lesson as a marked, dated addition without touching its text, count repeats, propose where each repeated lesson should live (a hook or test, a skill line, a rule line, or the record only) for the human to approve one by one, then hand the human a link to the file and ask which lessons they want added. Use when the start-of-session reminder says the lessons clean is due, or when the human says "clean the lessons", "weekly lessons", "run the lessons clean".
---

# Lessons clean

`docs/LESSONS.md` is the kit's one lessons file. Sessions append raw lines under its last heading,
`## Submitted (not yet cleaned)`; this skill turns them into lessons once a week. Nothing reads the
file during work, so a lesson changes what sessions do only once it lives somewhere they load: a hook or
test, a line in a skill, or a rule line. The clean keeps the file faithful and proposes those homes; the
human approves each one before anything is built.

## 1. Read

- The Submitted list (every `- ` line under the last heading) and the `Last clean:` date.
- Empty list → say so and stop. The date does not move.

## 2. Sort each line

For each submitted line, find the nearest existing lesson (grep the rule's key words; read the
candidates whole). Then exactly one of:

| Case | Do |
|---|---|
| **New problem** | A new lesson: the next unused number, at the end of the last numbered section (open a new `## <theme> (harvest <date>)` section only when three or more new lessons share a theme) |
| **Same problem, a property the existing lesson lacks** | One line appended to that lesson: `*<TAG> (<YYYY-MM-DD>):* <the new property only>`, where TAG is the tag the file already uses for additions. The lesson's own text stays byte-identical |
| **Same problem, nothing new** | Count it: the lesson's `*Seen: <N> (last <YYYY-MM-DD>)*` line goes up by one (added with N = 2 when missing; the lesson itself counts as the first case). This count line is the only line a clean ever rewrites |
| **Two or more submissions on one problem** | One lesson holding every unique property of each |

## 3. Propose a home for each repeated lesson

A lesson whose `Seen` count is 2 or more, or one the human names, gets one proposed home: the
first row that fits.

| The rule | Home |
|---|---|
| Can be checked by a script and has no exceptions | A hook or test that fails on the old mistake |
| Applies inside one workflow | One line in that skill (name the skill and the step) |
| Needs judgment in every session | One line in the rules file sessions load (owner's notes say which), within its line budget |
| Applies only to some files | A rule scoped to those paths |
| None of these, or already covered | Record only; name what already covers it |

- Propose only; build nothing. The human approves, changes or refuses each home, one by one.
- Once a home is built and proven (a hook or test is shown to fail on the old mistake), the
  lesson gets `*Home: <path> (<YYYY-MM-DD>)*`. A line that a hook now enforces is deleted from
  the prose rules it came from.
- A lesson that already has a Home and is seen again: its home did not hold. Propose the next row
  up the table (a rule line becomes a hook or test).

## 4. Write in the file's format

- **Bold rule, then the reason.** One or two sentences of what goes wrong without the rule, about
  50 words in all. No incident counts, dates, row ids, project names or people in the lesson's text
  (the `Seen` and `Home` lines carry the count and date): the story becomes the reason, the reason stays.
- Cite related lessons the way the file does: `(see 42)`.
- **Condense once.** A lesson that carries a number is never reworded by a later clean; compression
  on compression loses information. The original author's lessons are never changed at all;
  anything for them is an addition, marked as in §2 (their `Seen` and `Home` lines are additions too).
- **Numbers are never reused.** A merge the human orders explicitly leaves `N. Retired, see M.` (or
  `N. Retired, removed.`); new lessons take the next unused number.

## 5. Close the list

Delete the folded lines, set `Last clean: <today>`, then prove the file still holds:

```bash
bash tests/lessons-clean.test.sh     # one Submitted section, valid date, unique ascending numbers
```

Commit by the owner's rules for kit changes (their local notes say where this file's edits go).

## 6. The human reviews

Report, in this order, then ask:

- each new lesson: its number and the rule in one line; each addition: the number it extends;
  each count raised: the number and its new count;
- the proposed homes as a numbered list (lesson number, its rule in a few words, the proposed home,
  why that row), for the human to answer one by one; build only the ones approved, each in its own
  change with its proof;
- a clickable link to `docs/LESSONS.md` (on WSL or Windows, a link the terminal can open, not a
  bare path);
- **"Any lessons you want added? One line each; they go in now."** Handle the answer with §2–§5
  in the same chat.
