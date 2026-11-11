#!/usr/bin/env python3
"""PreToolUse hook (orchestration-kit) for Edit|Write|MultiEdit on docs/orchestration/AGENT_BOARD.md:
refuses a NEW UTC clock stamp (`HH:MMZ`) more than 2 minutes ahead of the clock. Board times are read
from `date -u` in the writing command, never estimated; an estimate runs ahead of the clock and makes
the board's order of events wrong.

"New" = a stamp in the text being written that the replaced text (Edit, MultiEdit) or the file on disk
(Write) does not already hold, so editing a line that carries an old stamp is never refused.
"Ahead" = later than now by more than 2 and less than 720 minutes (a stamp from late yesterday is in
the past, not ahead). Approximations such as `3xZ` are not stamps and pass.

NO-OP unless the board's repo (its main checkout, the first `git worktree list` entry) carries the
opt-in marker docs/orchestration/.kit-hooks. Never breaks a tool call: any error = allow.
Test mode: BOARD_STAMP_NOW=HH:MM fakes the clock (UTC); BOARD_STAMP_NO_OPTIN=1 skips the marker check.
"""
import datetime
import json
import os
import re
import subprocess
import sys

STAMP = re.compile(r"(?<![0-9:])([01][0-9]|2[0-3]):([0-5][0-9])Z\b")
BOARD = "docs/orchestration/AGENT_BOARD.md"


def stamps(text):
    return {m.group(0) for m in STAMP.finditer(text or "")}


def opted_in(path):
    if os.environ.get("BOARD_STAMP_NO_OPTIN"):
        return True
    try:
        out = subprocess.run(["git", "-C", os.path.dirname(path) or ".", "worktree", "list", "--porcelain"],
                             capture_output=True, text=True, timeout=5).stdout
        main = out.splitlines()[0].split(" ", 1)[1] if out.startswith("worktree ") else ""
        return bool(main) and os.path.isfile(os.path.join(main, "docs/orchestration/.kit-hooks"))
    except Exception:
        return False


def now_minutes():
    fake = os.environ.get("BOARD_STAMP_NOW")
    if fake:
        h, m = fake.split(":")
        return int(h) * 60 + int(m)
    t = datetime.datetime.now(datetime.timezone.utc)
    return t.hour * 60 + t.minute


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    tool, inp = data.get("tool_name", ""), data.get("tool_input") or {}
    path = inp.get("file_path", "")
    if tool not in ("Edit", "Write", "MultiEdit") or not path.replace("\\", "/").endswith(BOARD):
        return 0
    if tool == "Edit":
        new, old = stamps(inp.get("new_string")), stamps(inp.get("old_string"))
    elif tool == "MultiEdit":
        edits = inp.get("edits") or []
        new = set().union(*(stamps(e.get("new_string")) for e in edits)) if edits else set()
        old = set().union(*(stamps(e.get("old_string")) for e in edits)) if edits else set()
    else:
        try:
            with open(path, encoding="utf-8") as f:
                old = stamps(f.read())
        except Exception:
            old = set()
        new = stamps(inp.get("content"))
    fresh = sorted(new - old)
    if not fresh or not opted_in(path):
        return 0
    now = now_minutes()
    ahead = [s for s in fresh if 2 < (int(s[:2]) * 60 + int(s[3:5]) - now) % 1440 < 720]
    if not ahead:
        return 0
    clock = "%02d:%02dZ" % divmod(now, 60)
    reason = ("Board stamp %s is ahead of the clock (now %s UTC). Read the time with `date -u +%%H:%%MZ` in the "
              "same command that writes the board; never estimate it." % (", ".join(ahead), clock))
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                                             "permissionDecisionReason": reason}}))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)
