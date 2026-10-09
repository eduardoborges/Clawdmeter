#!/usr/bin/env python3
"""Today's Claude Code activity for the device's Today workspace.

Read from the session transcripts (~/.claude/projects/**/*.jsonl), since
stats-cache.json only covers days Claude Code has already rolled up. Counts the
main conversation only, like /stats: subagent (sidechain) lines are skipped.
No third-party imports: the macOS daemon imports it, and the Linux daemon runs
it as a script.
"""
import datetime
import json
import sys
from collections import Counter
from pathlib import Path

try:
    from daemon.stats import _human
except ImportError:  # run as a script from daemon/
    from stats import _human


def roots() -> list[Path]:
    """The default config dir only, like the Stats workspace."""
    return [Path.home() / ".claude" / "projects"]


def _transcripts(dirs: list[Path], since: float) -> list[Path]:
    out = []
    for d in dirs:
        for p in d.rglob("*.jsonl"):
            try:
                if p.stat().st_mtime >= since:
                    out.append(p)
            except OSError:
                pass
    return out


def signature(dirs: list[Path], today: datetime.date) -> str:
    """Changes when a transcript is written or the day rolls over."""
    midnight = datetime.datetime.combine(today, datetime.time()).timestamp()
    newest = max((p.stat().st_mtime for p in _transcripts(dirs, midnight)), default=0)
    return f"{today.isoformat()}@{newest:.0f}"


def _is_prompt(d: dict) -> bool:
    """A user line typed by a person, not a tool result or a command's output."""
    if "turnOrigin" in d:
        return d["turnOrigin"] == "human"
    # Claude Code before ~2.1.274 doesn't write turnOrigin.
    content = (d.get("message") or {}).get("content")
    return isinstance(content, str) and not d.get("isMeta") and not content.startswith("<")


def today_message(dirs: list[Path], today: datetime.date) -> dict:
    """{"k":"td","h":<24 chars, messages per hour as '0'..'8'>,"v":[[label, value] x6]}."""
    start = datetime.datetime.combine(today, datetime.time()).astimezone()
    utc = lambda t: t.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
    lo, hi = utc(start), utc(start + datetime.timedelta(days=1))
    prompts = 0
    hours = [0] * 24
    sessions, projects = set(), Counter()
    tools, messages = set(), set()
    tokens = 0
    for path in _transcripts(dirs, start.timestamp()):
        try:
            f = open(path, "rb")
        except OSError:
            continue
        with f:
            for raw in f:
                # Cheap date check before parsing: most of a transcript's bytes
                # are older lines.
                i = raw.find(b'"timestamp":"')
                if i < 0 or not lo <= raw[i + 13:i + 32].decode(errors="replace") < hi:
                    continue
                try:
                    d = json.loads(raw)
                except ValueError:
                    continue
                kind = d.get("type")
                if kind not in ("user", "assistant") or d.get("isSidechain"):
                    continue
                ts = datetime.datetime.fromisoformat(d["timestamp"].replace("Z", "+00:00"))
                hours[ts.astimezone().hour] += 1
                sessions.add(d.get("sessionId"))
                projects[Path(d.get("cwd") or "?").name] += 1
                if kind == "user":
                    prompts += _is_prompt(d)
                    continue
                m = d.get("message") or {}
                for block in m.get("content") or []:
                    if isinstance(block, dict) and block.get("type") == "tool_use":
                        tools.add(block.get("id"))
                # Streaming writes one line per content block, each repeating
                # the message's usage: count it once.
                if m.get("id") and m["id"] not in messages:
                    messages.add(m["id"])
                    u = m.get("usage") or {}
                    tokens += sum(u.get(k, 0) for k in ("input_tokens", "output_tokens",
                                                       "cache_read_input_tokens",
                                                       "cache_creation_input_tokens"))
    peak = max(hours)
    levels = "".join(str((8 * h + peak - 1) // peak) if h else "0" for h in hours)
    top = projects.most_common(1)[0][0] if projects else "-"
    return {"k": "td", "h": levels, "v": [
        ["Prompts", f"{prompts:,}"],
        ["Tool calls", f"{len(tools):,}"],
        ["Tokens", _human(tokens)],
        ["Sessions", str(len(sessions))],
        ["Top project", top[:12]],
        ["Active hours", str(sum(1 for h in hours if h))],
    ]}


if __name__ == "__main__":
    # today.py [previous signature]: prints "sig<TAB>message", or just the
    # signature when nothing changed since the previous one.
    dirs, today = roots(), datetime.date.today()
    sig = signature(dirs, today)
    if sys.argv[1:] == [sig]:
        print(sig)
    else:
        print(sig + "\t" + json.dumps(today_message(dirs, today), separators=(",", ":")))
