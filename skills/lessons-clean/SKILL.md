---
name: lessons-clean
description: Weekly clean of docs/LESSONS.md — fold the lines under "## Submitted" into numbered lessons in the file's own format (condensed once, never reworded later), merge submissions that share a problem, add genuinely new information to an existing lesson as a marked, dated addition without touching its text, then hand the human a link to the file and ask which lessons they want added. Use when the start-of-session reminder says the lessons clean is due, or when the human says "clean the lessons", "weekly lessons", "run the lessons clean".
---

# Lessons clean

`docs/LESSONS.md` is the kit's one lessons file. Sessions append raw lines under its last heading,
`## Submitted (not yet cleaned)`; this skill turns them into lessons once a week. Nothing reads the
file during work, so a clean costs no session anything; what it protects is the file's fidelity.

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
| **Same problem, nothing new** | Drop the line. A "broken again" case adds nothing to the file |
| **Two or more submissions on one problem** | One lesson holding every unique property of each |

## 3. Write in the file's format

- **Bold rule, then the reason.** One or two sentences of what goes wrong without the rule, about
  50 words in all. No incident counts, dates, row ids, project names or people: the story becomes
  the reason, the reason stays.
- Cite related lessons the way the file does: `(see 42)`.
- **Condense once.** A lesson that carries a number is never reworded by a later clean; compression
  on compression loses information. The original author's lessons are never changed at all;
  anything for them is an addition, marked as in §2.
- **Numbers are never reused.** A merge the human orders explicitly leaves `N. Retired, see M.` (or
  `N. Retired, removed.`); new lessons take the next unused number.

## 4. Close the list

Delete the folded lines, set `Last clean: <today>`, then prove the file still holds:

```bash
bash tests/lessons-clean.test.sh     # one Submitted section, valid date, unique ascending numbers
```

Commit by the owner's rules for kit changes (their local notes say where this file's edits go).

## 5. The human reviews

Report, in this order, then ask:

- each new lesson: its number and the rule in one line; each addition: the number it extends;
  the count dropped;
- a clickable link to `docs/LESSONS.md` (on WSL or Windows, a link the terminal can open, not a
  bare path);
- **"Any lessons you want added? One line each; they go in now."** Handle the answer with §2–§4
  in the same chat.
