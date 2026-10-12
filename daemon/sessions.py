#!/usr/bin/env python3
"""Open Claude Code sessions for the device's Sessions workspace.

attention-hook.sh leaves one file per session in SESSIONS_DIR holding the
project name, the last hook event, the last tool and when the current task
started; the file's mtime says when the last event happened.
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
CONFIG_FILE = SESSIONS_DIR.parent / "config"
# The corner Clawd acts out the newest working session's last tool, until that
# session goes quiet for ACTIVE_MAX (an interrupted reply never fires Stop).
ACTIVE_MAX = 600
TYPING = {"Bash", "Edit", "Write", "MultiEdit", "NotebookEdit"}
LOOKING = {"Read", "Grep", "Glob", "LS", "WebSearch", "WebFetch"}
# A task that ran at least `done_after` minutes gets a celebration when it
# finishes, announced for DONE_FRESH seconds.
DONE_AFTER = 5
DONE_FRESH = 60


def _ascii(text: str, limit: int) -> str:
    """The device fonts are ASCII only."""
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return " ".join(text.split())[:limit]


def _setting(name: str, path: Path) -> str:
    try:
        for line in path.read_text().splitlines():
            key, sep, val = line.split("#", 1)[0].partition("=")
            if sep and key.strip().lower() == name:
                return val.strip().lower()
    except OSError:
        pass
    return ""


def _activity(tool: str) -> str:
    """The splash animation the corner Clawd plays for this tool."""
    if tool in TYPING:
        return "laptop"
    if tool in LOOKING:
        return "magnifier"
    return "cloud"


def sessions_message(path: Path = SESSIONS_DIR, now: float | None = None,
                     config: Path = CONFIG_FILE) -> dict:
    """{"k":"ss","v":[[project, state, minutes since], ...]}, sessions that need
    you first, then working, then done, newest first within each. Deletes
    files older than MAX_AGE. Adds "a" (what the newest working session is
    doing) and "dn" (when a long task just finished, plus "b" to beep)."""
    now = time.time() if now is None else now
    done_after = _setting("done_after", config)
    done_after = int(done_after) if done_after.isdigit() else DONE_AFTER
    rows = []
    active = None   # (mtime, tool) of the newest working session
    done = None     # mtime of the newest long task that just finished
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
        start, fin = d.get("st"), d.get("fin")
        if (state == "d" and done_after and isinstance(start, (int, float))
                and isinstance(fin, (int, float)) and now - fin < DONE_FRESH
                and fin - start >= done_after * 60 and (not done or fin > done)):
            done = fin
    rows.sort(key=lambda r: ("awd".index(r[0]), -r[1]))
    msg = {"k": "ss", "v": [[p, s, int(max(0, now - t) // 60)] for s, t, p in rows[:ROWS]]}
    if active:
        msg["a"] = _activity(active[1])
    if done:
        msg["dn"] = int(done)
        if _setting("beep", config) == "on":
            msg["b"] = 1
    return msg


if __name__ == "__main__":
    print(json.dumps(sessions_message(), separators=(",", ":")))
