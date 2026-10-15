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

    /// The first value of `key`, lowercased, or "" when it isn't set.
    public func value(_ key: String) -> String {
        pairs.first { $0.key == key }?.value.lowercased() ?? ""
    }

    /// The first value of `key` that is one of `allowed`, lowercased.
    public func choice(_ key: String, _ allowed: Set<String>, default fallback: String) -> String {
        pairs.lazy.map { ($0.key, $0.value.lowercased()) }
            .first { $0.0 == key && allowed.contains($0.1) }?.1 ?? fallback
    }
}
