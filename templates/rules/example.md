---
paths:
  - "<replace with a glob, e.g. src/api/**/*.ts>"
---
<!-- orchestration-kit — a rules file: Claude Code loads it ONLY when a session reads, writes or edits a file matching
     `paths:` (standard globs, braces allowed: src/**/*.{ts,tsx}). Until the placeholder above is replaced it matches
     nothing and never loads. Copy this file to .claude/rules/<area>.md, one file per area; keep each short: these
     lines are paid for on every turn that touches a matching file. Rules, not stories: the reason goes in memory. -->
# <Area> rules

- <the rule, as an imperative, with the exact command, flag or location when one exists>
- <another>
- Reuse before adding: check the existing modules, helpers and dependencies first.
- Comments state current behavior only: no history, no "there is no X", no comparison to removed code.
