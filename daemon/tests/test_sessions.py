#!/usr/bin/env python3
"""Sessions workspace message. Run: python -m pytest daemon/tests/test_sessions.py -q"""
import json
import os

from daemon.sessions import MAX_AGE, ROWS, sessions_message


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
