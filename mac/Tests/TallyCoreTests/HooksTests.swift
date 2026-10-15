import Foundation
import Testing
@testable import TallyCore

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
