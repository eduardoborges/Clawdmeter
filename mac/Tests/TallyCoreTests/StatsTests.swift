import Foundation
import Testing
@testable import TallyCore

// The same cases as daemon/tests/test_stats.py.

private func decode(_ msg: JSON) -> [String: Any] {
    try! JSONSerialization.jsonObject(with: Data(msg.encoded.utf8)) as! [String: Any]
}

private func values(_ msg: [String: Any]) -> [String: String] {
    Dictionary(uniqueKeysWithValues: (msg["v"] as! [[String]]).map { ($0[0], $0[1]) })
}

private let statsToday = Day(iso: "2026-10-08")!   // a Thursday

private func statsCache(_ activeDays: [String: Int]) -> [String: Any] {
    [
        "dailyActivity": activeDays.map { ["date": $0.key, "messageCount": $0.value] },
        "modelUsage": [
            "claude-opus-5": ["inputTokens": 6_000_000, "outputTokens": 140_000_000,
                              "cacheReadInputTokens": 42_000_000_000, "cacheCreationInputTokens": 0],
            "claude-haiku-4-5-20251001": ["outputTokens": 10],
        ],
        "totalSessions": 584,
        "firstSessionDate": "2026-06-17T21:08:14.857Z",
    ]
}

private func unpack(_ heat: String) -> [Int] {
    heat.unicodeScalars.flatMap { [Int($0.value - 65) / 5, Int($0.value - 65) % 5] }
}

@Test func heatmap() {
    let msgs = Stats.messages(cache: statsCache(["2026-10-08": 50, "2026-10-07": 5, "2026-04-12": 1]),
                              today: statsToday)
    let hm = decode(msgs[0]), n = hm["n"] as! Int
    #expect(n == 7 * 25 + 5)                       // 25 full weeks plus Sun..Thu
    let levels = unpack(hm["h"] as! String)
    #expect(levels[0] > 0 && levels[n - 1] == 4 && levels[n - 2] > 0)
    #expect(levels.filter { $0 != 0 }.count == 3)
    let months = hm["mo"] as! [[Any]]
    #expect(months.first! as NSArray == ["Apr", 0] as NSArray && months.last! as NSArray == ["Oct", 25] as NSArray)
    #expect(msgs.allSatisfy { $0.encoded.utf8.count <= 220 })
}

@Test func statsNumbers() {
    var days = Dictionary(uniqueKeysWithValues: (10...14).map { ("2026-09-\($0)", 3) })   // a 5-day run
    days.merge(["2026-10-07": 2, "2026-10-06": 2, "2026-10-04": 1]) { $1 }
    let v = values(decode(Stats.messages(cache: statsCache(days), today: statsToday)[1]))
    #expect(v["Longest streak"] == "5 days")
    #expect(v["Current streak"] == "2 days")       // today idle: counts from yesterday
    #expect(v["Active days"] == "8/114")
    #expect(v["Sessions"] == "584" && v["Total tokens"] == "42.1b")
    #expect(v["Favorite model"] == "Opus 5")
}

@Test func statsFormatting() {
    #expect(Stats.prettyModel("claude-opus-5-5") == "Opus 5.5")
    #expect(Stats.prettyModel("claude-haiku-4-5-20251001") == "Haiku 4.5")
    #expect(Stats.prettyModel("gpt-5.6-sol") == "gpt-5.6-sol")
    #expect([Stats.human(43_403_457_835), Stats.human(140_289_680), Stats.human(999)] == ["43.4b", "140.3m", "999"])
    #expect([Stats.grouped(1105), Stats.grouped(999), Stats.grouped(1_234_567)] == ["1,105", "999", "1,234,567"])
}

