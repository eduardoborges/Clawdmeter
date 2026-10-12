#!/usr/bin/env python3
"""Sessions workspace message. Run: python -m pytest daemon/tests/test_sessions.py -q"""
import json
import os

from daemon.sessions import ACTIVE_MAX, MAX_AGE, ROWS, sessions_message


def write(d, sid, project, event, mtime):
    f = d / sid
    f.write_text(json.dumps({"p": project, "e": event}))
    os.utime(f, (mtime, mtime))
    return f


def test_states_order_and_age(tmp_path):
    now = 1_000_000.0
    write(tmp_path, "a", "done-old", "stop", now - 3600)
    write(tmp_path, "b", "Clawdmeter", "clear", now - 120)
    write(tmp_path, "c", "projeto ação", "alert", now - 30)
    write(tmp_path, "d", "done-new", "stop", now - 60)
    (tmp_path / ".d.123").write_text("{}")                       # hook's temp file
    write(tmp_path, "e", "x", "bogus", now)                      # unknown event
    assert sessions_message(tmp_path, now)["v"] == [
        ["projeto acao", "a", 0],
        ["Clawdmeter", "w", 2],
        ["done-new", "d", 1],
        ["done-old", "d", 60],
    ]


def test_prunes_stale_caps_rows_and_names(tmp_path):
    now = 1_000_000.0
    stale = write(tmp_path, "old", "old", "clear", now - MAX_AGE - 1)
    for i in range(ROWS + 2):
        write(tmp_path, f"s{i}", "a-very-long-project-name", "clear", now - i)
    rows = sessions_message(tmp_path, now)["v"]
    assert not stale.exists()
    assert len(rows) == ROWS
    assert rows[0][0] == "a-very-long-"


def test_empty(tmp_path):
    assert sessions_message(tmp_path / "missing", 0) == {"k": "ss", "v": []}


def write_full(d, sid, mtime, **fields):
    f = d / sid
    f.write_text(json.dumps({"p": "p", **fields}))
    os.utime(f, (mtime, mtime))


def test_activity_follows_newest_working_session(tmp_path):
    now = 1_000_000.0
    sessions = tmp_path
    write_full(sessions, "a", now - 30, e="clear", t="Grep")
    write_full(sessions, "b", now - 5, e="clear", t="Edit")
    write_full(sessions, "c", now - 1, e="stop", t="Bash")
    assert sessions_message(sessions, now)["a"] == "laptop"
    write_full(sessions, "b", now - ACTIVE_MAX, e="clear", t="Edit")
    assert sessions_message(sessions, now)["a"] == "magnifier"
    write_full(sessions, "a", now - 2, e="clear", t="")
    assert sessions_message(sessions, now)["a"] == "cloud"


def test_quiet_working_session_stops_animating(tmp_path):
    now = 1_000_000.0
    write_full(tmp_path, "a", now - ACTIVE_MAX, e="clear", t="Bash")
    assert "a" not in sessions_message(tmp_path, now)

