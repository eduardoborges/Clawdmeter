import Foundation

/// Claude Code's /stats numbers for the device's Stats workspace, ported from
/// daemon/stats.py.
public enum Stats {
    /// The cache behind /stats, in the default config dir.
    public static let cache = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".claude/stats-cache.json")
    static let weeks = 26   // heatmap columns; the firmware's STATS_WEEKS
    static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// claude-opus-5-5 -> Opus 5.5, claude-haiku-4-5-20251001 -> Haiku 4.5.
    static func prettyModel(_ model: String) -> String {
        guard model.hasPrefix("claude-") else { return model }
        let parts = model.dropFirst("claude-".count).split(separator: "-", omittingEmptySubsequences: false)
        let family = parts.first.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() } ?? ""
        let version = parts.dropFirst().filter { $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber)
            && !$0.isEmpty && $0.count < 8 }.joined(separator: ".")
        return "\(family) \(version)".trimmingCharacters(in: .whitespaces)
    }

    /// Token counts the way /stats prints them: 43.4b, 140.3m, 12.0k.
    public static func human(_ n: Double) -> String {
        for (div, unit) in [(1e9, "b"), (1e6, "m"), (1e3, "k")] where n >= div {
            return String(format: "%.1f%@", n / div, unit)
        }
        return String(Int(n))
    }

    /// 1105 -> "1,105", like Python's f"{n:,}".
    public static func grouped(_ n: Int) -> String {
        let digits = String(abs(n))
        var out = ""
        for (i, c) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 { out.append(",") }
            out.append(c)
        }
        return (n < 0 ? "-" : "") + out
    }

    static func days(_ n: Int) -> String { n == 1 ? "\(n) day" : "\(n) days" }

    /// The numbers behind the Stats workspace.
    public struct Summary {
        public var start: Day               // the heatmap's first day, a Sunday
        public var perDay: [Int]            // messages per day from start through today
        public var levels: [Int]            // 0 to 4, by quarter of the active days
        public var months: [(String, Int)]  // month labels by week column
        public var values: [(String, String)]
    }

    /// "hm", a heatmap of messages per day (week columns from the oldest
    /// Sunday, levels 0 to 4 by quarter of the active days, two days per char,
    /// month labels by column), and "st", six formatted numbers.
    public static func messages(cache: [String: Any], today: Day) -> [JSON] {
        messages(from: summary(cache: cache, today: today))
    }

    public static func messages(from s: Summary) -> [JSON] {
        var levels = s.levels
        if levels.count % 2 == 1 { levels.append(0) }
        let heat = String(stride(from: 0, to: levels.count, by: 2).map {
            Character(Unicode.Scalar(UInt8(65 + levels[$0] * 5 + levels[$0 + 1])))
        })
        return [
            .object([("k", .string("hm")), ("n", .int(s.perDay.count)), ("h", .string(heat)),
                     ("mo", .array(s.months.map { .array([.string($0.0), .int($0.1)]) }))]),
            .object([("k", .string("st")),
                     ("v", .array(s.values.map { .array([.string($0.0), .string($0.1)]) }))]),
        ]
    }

    public static func summary(cache: [String: Any], today: Day) -> Summary {
        var counts: [String: Int] = [:]
        for a in cache["dailyActivity"] as? [[String: Any]] ?? [] {
            if let date = a["date"] as? String { counts[date] = (a["messageCount"] as? Int) ?? 0 }
        }
        let sinceSunday = today.weekday - 1
        let start = today.adding(-(sinceSunday + 7 * (weeks - 1)))
        let n = 7 * (weeks - 1) + sinceSunday + 1
        let window = (0..<n).map { counts[start.adding($0).iso] ?? 0 }
        let ranked = window.filter { $0 != 0 }.sorted()
        // Level by rank among active days, so the busiest quarter always reads 4.
        let levels = window.map { v -> Int in
            guard v != 0 else { return 0 }
            let rank = ranked.lastIndex { $0 <= v }! + 1
            return (4 * rank + ranked.count - 1) / ranked.count
        }

        var monthLabels: [(String, Int)] = []
        var last: Int?
        for col in 0..<weeks {
            let month = start.adding(7 * col).month
            if month != last {
                monthLabels.append((months[month - 1], col))
                last = month
            }
        }
        if monthLabels.count > 1 && monthLabels[1].1 < 3 {
            monthLabels.removeFirst()   // only a sliver of the oldest month: its label would overlap
        }

        let active = counts.filter { $0.value != 0 }.keys.compactMap(Day.init(iso:)).sorted()
        var longest = 0, run = 0
        for (i, day) in active.enumerated() {
            run = i > 0 && active[i - 1].adding(1) == day ? run + 1 : 1
            longest = max(longest, run)
        }
        let activeSet = Set(active)
        var day = activeSet.contains(today) ? today : today.adding(-1)
        var current = 0
        while activeSet.contains(day) {
            current += 1
            day = day.adding(-1)
        }

        let usage = cache["modelUsage"] as? [String: [String: Any]] ?? [:]
        func tokens(_ u: [String: Any]) -> Double {
            ["inputTokens", "outputTokens", "cacheReadInputTokens", "cacheCreationInputTokens"]
                .reduce(0) { $0 + ((u[$1] as? NSNumber)?.doubleValue ?? 0) }
        }
        let favorite = usage.max { tokens($0.value) < tokens($1.value) }?.key ?? ""
        let firstText = (cache["firstSessionDate"] as? String).map { String($0.prefix(10)) } ?? today.iso
        let first = Day(iso: firstText) ?? today
        let values: [(String, String)] = [
            ("Sessions", grouped((cache["totalSessions"] as? Int) ?? 0)),
            ("Total tokens", human(usage.values.reduce(0) { $0 + tokens($1) })),
            ("Active days", "\(active.count)/\(today.daysSince(first) + 1)"),
            ("Longest streak", days(longest)),
            ("Favorite model", String(prettyModel(favorite).prefix(15))),
            ("Current streak", days(current)),
        ]
        return Summary(start: start, perDay: window, levels: levels, months: monthLabels, values: values)
    }

    /// The summary from the cache file, or nil when it's missing or unreadable.
    public static func loadSummary(from file: URL = cache, today: Day = Day()) -> Summary? {
        guard let data = try? Data(contentsOf: file),
              let cache = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return summary(cache: cache, today: today)
    }

    /// Today's messages, or none when the cache is missing or unreadable.
    public static func load(from file: URL = cache, today: Day = Day()) -> [JSON] {
        loadSummary(from: file, today: today).map(messages(from:)) ?? []
    }
}

/// A calendar day in the local time zone.
public struct Day: Hashable, Comparable {
    static let calendar = Calendar(identifier: .gregorian)
    let date: Date   // noon, so adding days never trips over DST

    public init(_ date: Date = .now) {
        self.date = Day.calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
    }

    public init?(iso: String) {
        let f = DateFormatter()
        f.calendar = Day.calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: iso) else { return nil }
        self.init(date)
    }

    public var iso: String {
        let c = Day.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    var weekday: Int { Day.calendar.component(.weekday, from: date) }   // Sunday = 1
    var month: Int { Day.calendar.component(.month, from: date) }
    /// Local midnight at the start of this day.
    var midnight: Date { Day.calendar.startOfDay(for: date) }

    public func adding(_ days: Int) -> Day { Day(Day.calendar.date(byAdding: .day, value: days, to: date)!) }
    func daysSince(_ other: Day) -> Int { Day.calendar.dateComponents([.day], from: other.date, to: date).day! }
    public static func < (a: Day, b: Day) -> Bool { a.date < b.date }
}
