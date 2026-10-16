import Foundation

/// Which Claude Code hooks call attention-hook.sh, read from
/// ~/.claude/settings.json, and the installer that points them at the copy
/// inside the app.
public enum Hooks {
    public static let settings = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/settings.json")
    public static let backup = Config.file.deletingLastPathComponent().appending(path: "claude-settings.backup.json")
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
    /// Tally's hooks as the README lists them: event, matcher and the script's argument.
    static let entries: [(event: String, matcher: String?, arg: String)] = [
        ("Notification", "permission_prompt|elicitation_dialog", "alert"),
        ("PreToolUse", "AskUserQuestion", "alert"),
        ("PreToolUse", "*", "tool"),
        ("UserPromptSubmit", nil, "clear"),
        ("PostToolUse", "*", "clear"),
        ("Stop", nil, "stop"),
        ("SubagentStop", nil, "subagent"),
        ("SessionEnd", nil, "end"),
    ]

    /// The events whose hooks run attention-hook.sh.
    public static func installed(in file: URL = settings) -> Set<String> {
        Set(calls(in: file).map(\.event))
    }

    /// Whether all of Tally's hooks are there and every attention-hook.sh call
    /// runs `script`, so none points at an old copy.
    public static func current(script: String, in file: URL = settings) -> Bool {
        let calls = calls(in: file)
        return Set(calls.map(\.event)) == Set(events.map(\.event)) && calls.allSatisfy { $0.command.contains(script) }
    }

    /// Swaps every attention-hook.sh call for Tally's set, run through /bin/sh
    /// from `script`, and leaves the rest of the file alone. Writes through a
    /// symlink (dotfiles keep settings.json in a repo) and copies the old file
    /// to `backup` first. A file that isn't a JSON object throws instead of
    /// being replaced.
    public static func install(script: String, in file: URL = settings, backup: URL = backup) throws {
        let file = file.resolvingSymlinksInPath()
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: file) {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CocoaError(.fileReadCorruptFile)
            }
            json = object
            try FileManager.default.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: backup, options: .atomic)
        }
        var hooks = json["hooks"] as? [String: Any] ?? [:]
        for event in Array(hooks.keys) {
            let kept = (hooks[event] as? [Any] ?? []).compactMap { item -> Any? in
                guard var entry = item as? [String: Any], let list = entry["hooks"] as? [Any] else { return item }
                let others = list.filter { !runsScript($0) }
                if others.count == list.count { return item }
                if others.isEmpty { return nil }
                entry["hooks"] = others
                return entry
            }
            hooks[event] = kept.isEmpty ? nil : kept
        }
        for hook in entries {
            var entry: [String: Any] = ["hooks": [["type": "command", "command": "/bin/sh '\(script)' \(hook.arg)"]]]
            if let matcher = hook.matcher { entry["matcher"] = matcher }
            hooks[hook.event] = (hooks[hook.event] as? [Any] ?? []) + [entry]
        }
        json["hooks"] = hooks
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: file, options: .atomic)
    }

    private static func runsScript(_ hook: Any) -> Bool {
        ((hook as? [String: Any])?["command"] as? String)?.contains("attention-hook.sh") == true
    }

    private static func calls(in file: URL) -> [(event: String, command: String)] {
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else { return [] }
        var found: [(event: String, command: String)] = []
        for (event, entries) in hooks {
            for case let entry as [String: Any] in entries as? [Any] ?? [] {
                for case let hook as [String: Any] in entry["hooks"] as? [Any] ?? [] {
                    if let command = hook["command"] as? String, command.contains("attention-hook.sh") {
                        found.append((event, command))
                    }
                }
            }
        }
        return found
    }
}
