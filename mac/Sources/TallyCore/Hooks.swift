import Foundation

/// Which Claude Code hooks call attention-hook.sh, read from
/// ~/.claude/settings.json. Tally only reads the file; it never edits it.
public enum Hooks {
    public static let settings = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/settings.json")
    /// The events the README sets up, and what each one feeds.
    public static let events: [(event: String, feeds: String)] = [
        ("Notification", "Alerts when a session needs you"),
        ("PreToolUse", "The corner Clawd and what each session is doing"),
        ("UserPromptSubmit", "Ending an alert once you answer"),
        ("PostToolUse", "Ending an alert after a tool runs"),
        ("Stop", "Done sessions and celebrations"),
        ("SubagentStop", "The running agents count"),
        ("SessionEnd", "Taking closed sessions off the list"),
    ]

    /// The events whose hooks run attention-hook.sh.
    public static func installed(in file: URL = settings) -> Set<String> {
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else { return [] }
        var found = Set<String>()
        for (event, entries) in hooks {
            for case let entry as [String: Any] in entries as? [Any] ?? [] {
                for case let hook as [String: Any] in entry["hooks"] as? [Any] ?? []
                where (hook["command"] as? String)?.contains("attention-hook.sh") == true {
                    found.insert(event)
                }
            }
        }
        return found
    }
}
