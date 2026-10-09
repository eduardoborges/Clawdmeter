#!/usr/bin/env python3
"""Today workspace message. Run: python -m pytest daemon/tests/test_today.py -q"""
import datetime
import json
import os

from daemon.today import signature, today_message

TODAY = datetime.date(2026, 10, 9)


def at(hour, minute=0, day=TODAY):
    """A local time as the transcripts write it: UTC with a Z."""
    t = datetime.datetime.combine(day, datetime.time(hour, minute)).astimezone()
    return t.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")


def line(kind, ts, **kw):
    # Compact, like Claude Code writes them (today.py looks for '"timestamp":"').
    return json.dumps({"type": kind, "timestamp": ts, "sessionId": kw.pop("sid", "s1"),
                       "cwd": kw.pop("cwd", "/p/Clawdmeter"), **kw}, separators=(",", ":"))


def assistant(ts, msg_id, blocks, usage, **kw):
    return line("assistant", ts, message={"id": msg_id, "content": blocks, "usage": usage}, **kw)


def test_counts_today_main_chain_once(tmp_path):
    usage = {"input_tokens": 10, "output_tokens": 90, "cache_read_input_tokens": 900}
    tool = {"type": "tool_use", "id": "t1"}
    lines = [
        line("user", at(23, 30, TODAY - datetime.timedelta(days=1)), turnOrigin="human"),  # yesterday
        line("user", at(9), turnOrigin="human"),
        line("user", at(9, 1), message={"content": [{"type": "tool_result"}]}),            # not a prompt
        assistant(at(9, 1), "m1", [{"type": "text"}], usage),
        assistant(at(9, 1), "m1", [tool], usage),                                          # same message, next block
        assistant(at(9, 2), "m2", [{"type": "tool_use", "id": "t2"}], usage, isSidechain=True),
        line("user", at(15), turnOrigin="human", sid="s2", cwd="/p/bulk"),
        line("attachment", at(16)),
    ]
    project = tmp_path / "proj"
    project.mkdir()
    (project / "a.jsonl").write_text("\n".join(lines) + "\n")
    msg = today_message([tmp_path], TODAY)
    assert msg["k"] == "td"
    assert dict(msg["v"]) == {"Prompts": "2", "Tool calls": "1", "Tokens": "1.0k", "Sessions": "2",
                              "Top project": "Clawdmeter", "Active hours": "2"}
    assert msg["h"][9] == "8" and msg["h"][15] == "2" and msg["h"].count("0") == 22


def test_old_files_skipped_and_signature_rolls_over(tmp_path):
    old = tmp_path / "old.jsonl"
    old.write_text(line("user", at(10), turnOrigin="human") + "\n")
    yesterday = datetime.datetime.combine(TODAY, datetime.time()).timestamp() - 60
    os.utime(old, (yesterday, yesterday))
    assert dict(today_message([tmp_path], TODAY)["v"])["Prompts"] == "0"
    assert signature([tmp_path], TODAY) != signature([tmp_path], TODAY + datetime.timedelta(days=1))
