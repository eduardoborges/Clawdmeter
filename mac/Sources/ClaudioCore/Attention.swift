import Foundation

/// The alerts attention-hook.sh leaves for the daemon: `attention` when a
/// session needs you, `clear-<session id>` when it moves on. Ported from the
/// macOS daemon.
public enum Attention {
    public static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".config/claude-usage-monitor")
    static let maxAge = 60.0

    public struct Alert {
        public var message: String
        public var session: String
        public var time: Double   // when the hook wrote it
    }

    /// The device fonts are ASCII only: drop accents, collapse whitespace, cap.
    static func toASCII(_ text: String, _ limit: Int) -> String {
        let t = Sessions.ascii(text, .max)
        guard t.count > limit else { return t }
        return String(t.prefix(limit - 3)).replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression) + "..."
    }

    /// Consumes the attention file. Only a fresh one counts, so a file written
    /// while the device was away doesn't beep on reconnect. A bare `touch` with
    /// no JSON still beeps, just without a message.
    public static func take(in dir: URL = directory, now: Double = Date().timeIntervalSince1970) -> Alert? {
        let file = dir.appending(path: "attention")
        guard let mtime = try? file.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate?.timeIntervalSince1970,
              let data = try? Data(contentsOf: file) else { return nil }
        try? FileManager.default.removeItem(at: file)
        guard now - mtime < maxAge else { return nil }
        let d = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return Alert(message: toASCII(Sessions.text(d["m"]), 120), session: Sessions.text(d["s"]), time: mtime)
    }

    /// Consumes every clear-<session id> file: [session id: when].
    public static func takeClears(in dir: URL = directory) -> [String: Double] {
        var clears: [String: Double] = [:]
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files where file.lastPathComponent.hasPrefix("clear-") {
            guard let mtime = try? file.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate?.timeIntervalSince1970 else { continue }
            clears[String(file.lastPathComponent.dropFirst("clear-".count))] = mtime
            try? FileManager.default.removeItem(at: file)
        }
        return clears
    }

    /// Encodes a payload for one write of at most `limit` bytes: shortens the
    /// alert message, then drops it, until it fits. Other messages pass as is.
    public static func encode(_ payload: [(String, JSON)], limit: Int) -> String {
        var pairs = payload
        var data = JSON.object(pairs).encoded
        guard let i = pairs.firstIndex(where: { $0.0 == "m" }), case .string(var message) = pairs[i].1 else { return data }
        while data.utf8.count > limit && !message.isEmpty {
            message = String(message.prefix(max(0, message.count - (data.utf8.count - limit) - 3)))
                .replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
            pairs[i].1 = .string(message.isEmpty ? "" : message + "...")
            data = JSON.object(pairs).encoded
        }
        if data.utf8.count > limit {
            pairs.remove(at: i)
            data = JSON.object(pairs).encoded
        }
        return data
    }
}
