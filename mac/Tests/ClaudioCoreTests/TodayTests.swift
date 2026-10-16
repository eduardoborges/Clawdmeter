import Foundation
import Testing
@testable import ClaudioCore

// The same cases as daemon/tests/test_today.py.

private func decode(_ msg: JSON) -> [String: Any] {
    try! JSONSerialization.jsonObject(with: Data(msg.encoded.utf8)) as! [String: Any]
}

private func values(_ msg: [String: Any]) -> [String: String] {
    Dictionary(uniqueKeysWithValues: (msg["v"] as! [[String]]).map { ($0[0], $0[1]) })
}

private let today = Day(iso: "2026-10-09")!

/// A local time as the transcripts write it: UTC with a Z.
private func at(_ hour: Int, _ minute: Int = 0, day: Day = today) -> String {
    let date = Day.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day.midnight)!
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    return f.string(from: date)
}

private func line(_ kind: String, _ ts: String, sid: String = "s1", cwd: String = "/p/Clawdmeter",
                  _ extra: [String: Any] = [:]) -> String {
    let fields: [String: Any] = ["type": kind, "timestamp": ts, "sessionId": sid, "cwd": cwd].merging(extra) { $1 }
    return String(decoding: try! JSONSerialization.data(withJSONObject: fields, options: .withoutEscapingSlashes),
                  as: UTF8.self)
}

private func assistant(_ ts: String, _ id: String, _ blocks: [[String: Any]], _ usage: [String: Int],
                       _ extra: [String: Any] = [:]) -> String {
    line("assistant", ts, ["message": ["id": id, "content": blocks, "usage": usage]].merging(extra) { $1 })
}

@Test func countsTodayMainChainOnce() throws {
    let usage = ["input_tokens": 10, "output_tokens": 90, "cache_read_input_tokens": 900]
    let lines = [
        line("user", at(23, 30, day: today.adding(-1)), ["turnOrigin": "human"]),           // yesterday
        line("user", at(9), ["turnOrigin": "human"]),
        line("user", at(9, 1), ["message": ["content": [["type": "tool_result"]]]]),        // not a prompt
        assistant(at(9, 1), "m1", [["type": "text"]], usage),
        assistant(at(9, 1), "m1", [["type": "tool_use", "id": "t1"]], usage),               // same message, next block
        assistant(at(9, 2), "m2", [["type": "tool_use", "id": "t2"]], usage, ["isSidechain": true]),
        line("user", at(15), sid: "s2", cwd: "/p/bulk", ["turnOrigin": "human"]),
        line("user", at(15, 5), sid: "s2", cwd: "/p/bulk", ["message": ["content": "older Claude Code: no turnOrigin"]]),
        line("user", at(15, 6), sid: "s2", ["message": ["content": "<local-command-stdout>ok</local-command-stdout>"]]),
        line("attachment", at(16)),
    ]
    let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let project = dir.appending(path: "proj")
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    try (lines.joined(separator: "\n") + "\n").write(to: project.appending(path: "a.jsonl"), atomically: true, encoding: .utf8)
    let msg = decode(Today.message([dir], today: today))
    #expect(msg["k"] as? String == "td")
    #expect(values(msg) == ["Prompts": "3", "Tool calls": "1", "Tokens": "1.0k", "Sessions": "2",
                            "Top project": "Clawdmeter", "Active hours": "2"])
    let h = Array(msg["h"] as! String)
    #expect(h[9] == "8" && h[15] == "6" && h.filter { $0 == "0" }.count == 22)
}

@Test func oldFilesSkippedAndSignatureRollsOver() throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let old = dir.appending(path: "old.jsonl")
    try (line("user", at(10), ["turnOrigin": "human"]) + "\n").write(to: old, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.modificationDate: today.midnight.addingTimeInterval(-60)], ofItemAtPath: old.path)
    #expect(values(decode(Today.message([dir], today: today)))["Prompts"] == "0")
    #expect(Today.signature([dir], today: today) != Today.signature([dir], today: today.adding(1)))
}
