import Foundation

/// Today's Claude Code activity for the device's Today workspace, ported from
/// daemon/today.py. Read from the session transcripts, since stats-cache.json
/// only covers days Claude Code has already rolled up. Counts the main
/// conversation only, like /stats: subagent (sidechain) lines are skipped.
public enum Today {
    /// The default config dir only, like the Stats workspace.
    public static let roots = [FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/projects")]
    static let marker = Data(#""timestamp":""#.utf8)

    static func transcripts(_ dirs: [URL], since: Date) -> [URL] {
        dirs.flatMap { dir -> [URL] in
            let walker = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
            return (walker?.allObjects as? [URL] ?? []).filter {
                $0.pathExtension == "jsonl" &&
                    ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) >= since
            }
        }
    }

    /// Changes when a transcript is written or the day rolls over.
    public static func signature(_ dirs: [URL] = roots, today: Day = Day()) -> String {
        let newest = transcripts(dirs, since: today.midnight)
            .compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
            .map(\.timeIntervalSince1970).max() ?? 0
        return "\(today.iso)@\(Int(newest.rounded()))"
    }

    /// A user line typed by a person, not a tool result or a command's output.
    static func isPrompt(_ d: [String: Any]) -> Bool {
        if let origin = d["turnOrigin"] { return origin as? String == "human" }
        // Claude Code before ~2.1.274 doesn't write turnOrigin.
        guard let content = (d["message"] as? [String: Any])?["content"] as? String else { return false }
        return (d["isMeta"] as? Bool) != true && !content.hasPrefix("<")
    }

    /// Today's numbers, as counted from the transcripts.
    public struct Summary {
        public var perHour = Array(repeating: 0, count: 24)   // messages in each local hour
        public var prompts = 0
        public var toolCalls = 0
        public var tokens = 0.0
        public var sessions = 0
        public var topProject = "-"
        public var activeHours: Int { perHour.filter { $0 != 0 }.count }

        public init(perHour: [Int] = Array(repeating: 0, count: 24), prompts: Int = 0, toolCalls: Int = 0,
                    tokens: Double = 0, sessions: Int = 0, topProject: String = "-") {
            (self.perHour, self.prompts, self.toolCalls) = (perHour, prompts, toolCalls)
            (self.tokens, self.sessions, self.topProject) = (tokens, sessions, topProject)
        }
    }

    public static func summary(_ dirs: [URL] = roots, today: Day = Day()) -> Summary {
        let utc = DateFormatter()
        utc.locale = Locale(identifier: "en_US_POSIX")
        utc.timeZone = TimeZone(identifier: "UTC")
        utc.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let lo = utc.string(from: today.midnight), hi = utc.string(from: today.adding(1).midnight)
        let iso = ISO8601DateFormatter(), isoFraction = ISO8601DateFormatter()
        isoFraction.formatOptions.insert(.withFractionalSeconds)

        var prompts = 0, hours = Array(repeating: 0, count: 24), tokens = 0.0
        var sessions = Set<String>(), tools = Set<String>(), messageIDs = Set<String>()
        var projects: [String: Int] = [:], projectOrder: [String] = []
        // ponytail: about 0.5 s for a day with 10 MB of transcripts, twice the Python
        // version. Fine at once a minute off the main thread; decode only the fields
        // used if it ever matters.
        for file in transcripts(dirs, since: today.midnight) {
            guard let data = try? Data(contentsOf: file, options: .mappedIfSafe) else { continue }
            for line in data.split(separator: 0x0A) {
                // Cheap date check before parsing: most of a transcript's bytes
                // are older lines.
                guard let r = line.range(of: marker) else { continue }
                let ts = String(decoding: line[r.upperBound...].prefix(19), as: UTF8.self)
                guard lo <= ts && ts < hi,
                      let d = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                      let kind = d["type"] as? String, kind == "user" || kind == "assistant",
                      (d["isSidechain"] as? Bool) != true,
                      let stamp = d["timestamp"] as? String,
                      let when = isoFraction.date(from: stamp) ?? iso.date(from: stamp) else { continue }
                hours[Day.calendar.component(.hour, from: when)] += 1
                sessions.insert(d["sessionId"] as? String ?? "")
                let cwd = d["cwd"] as? String ?? ""
                let project = URL(fileURLWithPath: cwd.isEmpty ? "?" : cwd).lastPathComponent
                if projects[project] == nil { projectOrder.append(project) }
                projects[project, default: 0] += 1
                if kind == "user" {
                    if isPrompt(d) { prompts += 1 }
                    continue
                }
                let m = d["message"] as? [String: Any] ?? [:]
                for case let block as [String: Any] in m["content"] as? [Any] ?? [] where block["type"] as? String == "tool_use" {
                    tools.insert(block["id"] as? String ?? "")
                }
                // Streaming writes one line per content block, each repeating
                // the message's usage: count it once.
                if let id = m["id"] as? String, !id.isEmpty, messageIDs.insert(id).inserted {
                    let u = m["usage"] as? [String: Any] ?? [:]
                    tokens += ["input_tokens", "output_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"]
                        .reduce(0) { $0 + ((u[$1] as? NSNumber)?.doubleValue ?? 0) }
                }
            }
        }
        let busiest = projects.values.max()
        return Summary(perHour: hours, prompts: prompts, toolCalls: tools.count, tokens: tokens,
                       sessions: sessions.count, topProject: projectOrder.first { projects[$0] == busiest } ?? "-")
    }

    /// `{"k":"td","h":<24 chars, messages per hour as '0'..'8'>,"v":[[label, value] x6]}`.
    public static func message(from s: Summary) -> JSON {
        let peak = s.perHour.max()!
        let levels = s.perHour.map { $0 == 0 ? "0" : String((8 * $0 + peak - 1) / peak) }.joined()
        let values: [(String, String)] = [
            ("Prompts", Stats.grouped(s.prompts)),
            ("Tool calls", Stats.grouped(s.toolCalls)),
            ("Tokens", Stats.human(s.tokens)),
            ("Sessions", String(s.sessions)),
            ("Top project", String(s.topProject.prefix(12))),
            ("Active hours", String(s.activeHours)),
        ]
        return .object([("k", .string("td")), ("h", .string(levels)),
                        ("v", .array(values.map { .array([.string($0.0), .string($0.1)]) }))])
    }

    public static func message(_ dirs: [URL] = roots, today: Day = Day()) -> JSON {
        message(from: summary(dirs, today: today))
    }
}
