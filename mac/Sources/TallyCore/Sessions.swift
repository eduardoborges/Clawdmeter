import Foundation

/// Open Claude Code sessions for the device's Sessions workspace, ported from
/// daemon/sessions.py and kept byte for byte equal to it.
///
/// attention-hook.sh leaves one file per session in `directory` holding the
/// project name, the git branch, the session's title, the last hook event,
/// the last tool and when the current task started; the file's mtime says
/// when the last event happened.
public enum Sessions {
    public static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".config/claude-usage-monitor/sessions")
    public static let rows = 6           // the firmware's SESSION_ROWS
    public static let maxBytes = 511     // the firmware's BLE buffer, less the terminator
    static let maxAge = 6.0 * 3600      // a session that crashed never fires SessionEnd
    // Hook event -> state: a = needs you, w = working, d = done.
    static let states = ["alert": "a", "clear": "w", "stop": "d"]
    // The corner Clawd acts out the newest working session's last tool, until
    // that session goes quiet for activeMax (an interrupted reply never fires Stop).
    static let activeMax = 600.0
    static let typing: Set = ["Bash", "Edit", "Write", "MultiEdit", "NotebookEdit"]
    static let looking: Set = ["Read", "Grep", "Glob", "LS", "WebSearch", "WebFetch"]
    // A task that ran at least `done_after` minutes gets a celebration when it
    // finishes, announced for doneFresh seconds.
    static let doneAfter = 5
    static let doneFresh = 60.0
    // What a working row says it is doing, from its last tool.
    static let verbs = ["Bash": "Running", "Edit": "Editing", "Write": "Editing",
                        "MultiEdit": "Editing", "NotebookEdit": "Editing", "Read": "Reading",
                        "Grep": "Searching", "Glob": "Searching", "LS": "Searching",
                        "WebSearch": "Browsing", "WebFetch": "Browsing", "Task": "Delegating",
                        "Agent": "Delegating", "TodoWrite": "Planning"]

    /// The device fonts are ASCII only: decompose accents, drop the rest and
    /// collapse whitespace like Python's str.split().
    static func ascii(_ text: String, _ limit: Int) -> String {
        let kept = text.decomposedStringWithCompatibilityMapping.unicodeScalars.filter(\.isASCII)
        let words = String(String.UnicodeScalarView(kept))
            .split { $0.isWhitespace || ("\u{1c}"..."\u{1f}").contains($0) }
        return String(words.joined(separator: " ").prefix(limit))
    }

    /// The splash animation the corner Clawd plays for this tool.
    static func activity(_ tool: String) -> String {
        typing.contains(tool) ? "laptop" : looking.contains(tool) ? "magnifier" : "cloud"
    }

    /// The row's second line: what a working session does, or that it waits for you.
    static func doing(_ state: String, _ tool: String, agents: Int = 0) -> String {
        if state == "a" { return "Needs your input" }
        if state != "w" { return "" }
        if agents > 0 {
            let n = "\(agents) agent\(agents > 1 ? "s" : "")"
            return agents < 10 ? n + " working" : n   // the firmware keeps 16 chars
        }
        if tool.isEmpty { return "Thinking" }
        return verbs[tool] ?? (tool.hasPrefix("mcp__") ? "Using MCP" : "Working")
    }

    /// `{"k":"ss","v":[["project | title", state, minutes, doing, branch], ...]}`,
    /// sessions that need you first, then working, then done. Within each, the
    /// newest alert, task start or finish comes first. See sessions.py for the
    /// optional "a", "dn", "b" and "n". Deletes files older than maxAge.
    public static func message(in directory: URL = directory, now: Double = Date().timeIntervalSince1970,
                               config: Config = Config()) -> JSON {
        let raw = config.value("done_after")   // digits only, like Python's isdigit()
        let doneAfter = !raw.isEmpty && raw.allSatisfy({ $0.isASCII && $0.isNumber }) ? Int(raw) ?? Self.doneAfter : Self.doneAfter
        struct Row { var state: String, order: Double, name: String, since: Double, doing: String, branch: String }
        var rows: [Row] = []
        var active: (last: Double, tool: String)?
        var done: Double?
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files where !file.lastPathComponent.hasPrefix(".") {
            guard let mtime = try? file.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate?.timeIntervalSince1970 else { continue }
            if now - mtime > maxAge {
                try? FileManager.default.removeItem(at: file)
                continue
            }
            guard let data = try? Data(contentsOf: file),
                  let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let state = states[text(d["e"])] else { continue }
            var state0 = state
            // Subagents the hook saw recently. One whose SubagentStop never came
            // (a killed agent) ages out like a quiet session.
            let agents = (d["ag"] as? [String: Any])?.values.compactMap(number)
                .filter { now - $0 < activeMax } ?? []
            if !agents.isEmpty && state0 == "d" { state0 = "w" }   // background agents still run
            let start = number(d["st"]), fin = number(d["fin"])
            let since = state0 == "w" ? start ?? mtime : mtime
            // Rows keep their place while sessions work: a working row moves
            // only when a new prompt starts its task, a done row when it finishes.
            let order = state0 == "w" ? since : state0 == "d" ? fin ?? mtime : mtime
            var name = ascii(text(d["p"], or: "?"), 12)
            let title = ascii(text(d["ti"]), 32)
            if !title.isEmpty {
                name = "\(name) | \(title)"
                if name.count > 32 { name = name.prefix(29) + "..." }   // about what a row shows
            }
            let tool = text(d["t"])
            rows.append(Row(state: state0, order: order, name: name, since: since,
                            doing: doing(state0, tool, agents: agents.count), branch: ascii(text(d["br"]), 24)))
            let last = ([mtime] + agents).max()!
            if state0 == "w" && now - last < activeMax && (active == nil || last > active!.last) {
                active = (last, tool)
            }
            if state0 == "d", doneAfter > 0, let start, let fin, now - fin < doneFresh,
               fin - start >= Double(doneAfter * 60), done == nil || fin > done! {
                done = fin
            }
        }
        rows.sort { a, b in
            let ga = "awd".firstIndex(of: Character(a.state))!, gb = "awd".firstIndex(of: Character(b.state))!
            return ga != gb ? ga < gb : a.order > b.order
        }
        var v: [JSON] = rows.prefix(Self.rows).map {
            .array([.string($0.name), .string($0.state), .int(Int((max(0, now - $0.since) / 60).rounded(.down))),
                    .string($0.doing), .string($0.branch)])
        }
        var tail: [(String, JSON)] = []
        if let active { tail.append(("a", .string(activity(active.tool)))) }
        if let done {
            tail.append(("dn", .int(Int(done))))
            if config.value("beep") == "on" { tail.append(("b", .int(1))) }
        }
        // Long titles can overflow the device's buffer. The last rows go first;
        // they rarely fit on the screen anyway. "n" counts every open session
        // when some are left out, for the device's "+N more".
        while true {
            var pairs: [(String, JSON)] = [("k", .string("ss")), ("v", .array(v))] + tail
            if rows.count > v.count { pairs.append(("n", .int(rows.count))) }
            let msg = JSON.object(pairs)
            if v.isEmpty || msg.encoded.utf8.count <= maxBytes { return msg }
            v.removeLast()
        }
    }

    static func text(_ value: Any?, or fallback: String = "") -> String {
        switch value {
        case let s as String where !s.isEmpty: return s
        case let n as NSNumber where !(n is Bool) && n != 0: return n.stringValue
        default: return fallback
        }
    }

    static func number(_ value: Any?) -> Double? {
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
        return n.doubleValue
    }
}
