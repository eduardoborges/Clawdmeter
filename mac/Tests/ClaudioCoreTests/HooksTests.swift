import Foundation
import Testing
@testable import ClaudioCore

@Test func installedHooksAreTheOnesCallingTheScript() throws {
    let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try #"""
    {"hooks": {
      "Stop": [{"hooks": [{"type": "command", "command": "/x/daemon/attention-hook.sh stop"}]}],
      "PreToolUse": [{"matcher": "*", "hooks": [{"type": "command", "command": "other-tool"}]},
                     {"matcher": "AskUserQuestion", "hooks": [{"type": "command", "command": "/x/attention-hook.sh alert"}]}],
      "SessionEnd": [{"hooks": [{"type": "command", "command": "something-else"}]}]
    }}
    """#.write(to: file, atomically: true, encoding: .utf8)
    #expect(Hooks.installed(in: file) == ["Stop", "PreToolUse"])
    #expect(Hooks.installed(in: file.appending(path: "missing")).isEmpty)
}

@Test func installReplacesOldCallsAndKeepsEverythingElse() throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let real = dir.appending(path: "dotfiles-settings.json")
    let link = dir.appending(path: "settings.json")
    let backup = dir.appending(path: "backup/settings.json")
    let original = #"""
    {"model": "opus", "hooks": {
      "Stop": [{"hooks": [{"type": "command", "command": "/repo/daemon/attention-hook.sh stop"}]}],
      "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "rtk hook"}]},
                     {"matcher": "*", "hooks": [{"type": "command", "command": "/repo/daemon/attention-hook.sh tool"},
                                                {"type": "command", "command": "other"}]}],
      "SessionStart": [{"hooks": [{"type": "command", "command": "journal.sh start"}]}]
    }}
    """#
    try original.write(to: real, atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
    let script = "/Applications/Claudio.app/Contents/Resources/attention-hook.sh"
    #expect(!Hooks.current(script: script, in: link))

    try Hooks.install(script: script, in: link, backup: backup)

    #expect(try String(contentsOf: backup, encoding: .utf8) == original)
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == real.path)
    #expect(Hooks.current(script: script, in: link))
    let text = try String(contentsOf: real, encoding: .utf8)
    #expect(text.contains(#""model": "opus""#) && !text.contains(#"" : "#) && text.hasSuffix("}\n"))
    let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: real)) as? [String: Any])
    #expect(json["model"] as? String == "opus")
    let hooks = try #require(json["hooks"] as? [String: [[String: Any]]])
    let commands = hooks.mapValues { $0.flatMap { ($0["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String } } }
    #expect(commands["SessionStart"] == ["journal.sh start"])
    #expect(commands["PreToolUse"] == ["rtk hook", "other", "/bin/sh '\(script)' alert", "/bin/sh '\(script)' tool"])
    #expect(commands["Stop"] == ["/bin/sh '\(script)' stop"])

    let once = try Data(contentsOf: real)
    try Hooks.install(script: script, in: link, backup: backup)
    #expect(try Data(contentsOf: real) == once)
}

@Test func installLeavesABrokenFileAlone() throws {
    let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try "[1, 2".write(to: file, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) {
        try Hooks.install(script: "/x/attention-hook.sh", in: file, backup: file.appendingPathExtension("bak"))
    }
    #expect(try String(contentsOf: file, encoding: .utf8) == "[1, 2")
}
