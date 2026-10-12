#!/usr/bin/env python3
"""Open Claude Code sessions for the device's Sessions workspace.

attention-hook.sh leaves one file per session in SESSIONS_DIR holding the
project name, the last hook event and the last tool; the file's mtime says
when the last event happened.
No third-party imports: the macOS daemon imports it, and the Linux daemon runs
it as a script that prints the message.
"""
import json
import time
import unicodedata
from pathlib import Path

SESSIONS_DIR = Path.home() / ".config" / "claude-usage-monitor" / "sessions"
ROWS = 6           # firmware's SESSION_ROWS must match
MAX_AGE = 6 * 3600  # a session that crashed never fires SessionEnd
# Hook event -> state: a = needs you, w = working, d = done (waiting for a prompt).
STATE = {"alert": "a", "clear": "w", "stop": "d"}
# The corner Clawd acts out the newest working session's last tool, until that
# session goes quiet for ACTIVE_MAX (an interrupted reply never fires Stop).
ACTIVE_MAX = 600
TYPING = {"Bash", "Edit", "Write", "MultiEdit", "NotebookEdit"}
LOOKING = {"Read", "Grep", "Glob", "LS", "WebSearch", "WebFetch"}


def _ascii(text: str, limit: int) -> str:
    """The device fonts are ASCII only."""
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return " ".join(text.split())[:limit]


def _activity(tool: str) -> str:
    """The splash animation the corner Clawd plays for this tool."""
    if tool in TYPING:
        return "laptop"
    if tool in LOOKING:
        return "magnifier"
    return "cloud"


def sessions_message(path: Path = SESSIONS_DIR, now: float | None = None) -> dict:
    """{"k":"ss","v":[[project, state, minutes since], ...]}, sessions that need
    you first, then working, then done, newest first within each. Deletes
    files older than MAX_AGE. Adds "a" (what the newest working session is
    doing)."""
    now = time.time() if now is None else now
    rows = []
    active = None   # (mtime, tool) of the newest working session
    for f in path.glob("[!.]*"):
        try:
            mtime = f.stat().st_mtime
            if now - mtime > MAX_AGE:
                f.unlink()
                continue
            d = json.loads(f.read_text())
        except (OSError, ValueError):
            continue
        state = STATE.get(d.get("e")) if isinstance(d, dict) else None
        if not state:
            continue
        rows.append((state, mtime, _ascii(str(d.get("p") or "?"), 12)))
        if state == "w" and now - mtime < ACTIVE_MAX and (not active or mtime > active[0]):
            active = (mtime, str(d.get("t") or ""))
    rows.sort(key=lambda r: ("awd".index(r[0]), -r[1]))
    msg = {"k": "ss", "v": [[p, s, int(max(0, now - t) // 60)] for s, t, p in rows[:ROWS]]}
    if active:
        msg["a"] = _activity(active[1])
    return msg


if __name__ == "__main__":
    print(json.dumps(sessions_message(), separators=(",", ":")))
