#!/usr/bin/env python3
"""Open Claude Code sessions for the device's Sessions workspace.

attention-hook.sh leaves one file per session in SESSIONS_DIR holding the
project name and the last hook event; the file's mtime says when it happened.
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


def _ascii(text: str, limit: int) -> str:
    """The device fonts are ASCII only."""
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return " ".join(text.split())[:limit]


def sessions_message(path: Path = SESSIONS_DIR, now: float | None = None) -> dict:
    """{"k":"ss","v":[[project, state, minutes since], ...]}, sessions that need
    you first, then working, then done, newest first within each. Deletes
    files older than MAX_AGE."""
    now = time.time() if now is None else now
    rows = []
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
        if state:
            rows.append((state, mtime, _ascii(str(d.get("p") or "?"), 12)))
    rows.sort(key=lambda r: ("awd".index(r[0]), -r[1]))
    return {"k": "ss", "v": [[p, s, int(max(0, now - t) // 60)] for s, t, p in rows[:ROWS]]}


if __name__ == "__main__":
    print(json.dumps(sessions_message(), separators=(",", ":")))
