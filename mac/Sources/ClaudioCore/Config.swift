import Foundation

/// The config file the daemons share: `key = value` lines, `#` starts a
/// comment, keys ignore case. Read it again on every use, so edits apply
/// without a restart.
public struct Config {
    public static let file = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".config/claude-usage-monitor/config")

    let pairs: [(key: String, value: String)]

    public init(file: URL = Config.file) {
        let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        pairs = text.split(whereSeparator: \.isNewline).compactMap { line in
            let line = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            guard let eq = line.firstIndex(of: "=") else { return nil }
            return (line[..<eq].trimmingCharacters(in: .whitespaces).lowercased(),
                    line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces))
        }
    }

    /// The last value of `key` as written, or "" when it isn't set.
    public func last(_ key: String) -> String {
        pairs.last { $0.key == key }?.value ?? ""
    }

    /// The first value of `key`, lowercased, or "" when it isn't set.
    public func value(_ key: String) -> String {
        pairs.first { $0.key == key }?.value.lowercased() ?? ""
    }

    /// Writes `key = value` into the file: the first line that sets `key` gets
    /// the new value and later ones go, so every reader agrees. Comments and
    /// other lines stay as they are.
    public static func set(_ key: String, _ value: String, in file: URL = Config.file) throws {
        let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        var lines = text.isEmpty ? [] : text.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        var placed = false
        lines = lines.compactMap { line in
            let code = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            guard let eq = code.firstIndex(of: "="),
                  code[..<eq].trimmingCharacters(in: .whitespaces).lowercased() == key else { return line }
            if placed { return nil }
            placed = true
            return "\(key) = \(value)"
        }
        if !placed { lines.append("\(key) = \(value)") }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
    }

    /// The first value of `key` that is one of `allowed`, lowercased.
    public func choice(_ key: String, _ allowed: Set<String>, default fallback: String) -> String {
        pairs.lazy.map { ($0.key, $0.value.lowercased()) }
            .first { $0.0 == key && allowed.contains($0.1) }?.1 ?? fallback
    }
}
