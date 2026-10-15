import Foundation

/// A JSON value with ordered keys, encoded the way Python's
/// `json.dumps(..., separators=(",", ":"))` does it. The daemons and this app
/// then send the same bytes, which matters for the device's 511-byte limit.
/// (Foundation's encoders escape "/" and reorder keys.)
public indirect enum JSON: Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case array([JSON])
    case object([(String, JSON)])

    public static func == (a: JSON, b: JSON) -> Bool { a.encoded == b.encoded }

    public var encoded: String {
        switch self {
        case .string(let s): return JSON.quote(s)
        case .int(let i): return String(i)
        case .bool(let b): return b ? "true" : "false"
        case .array(let items): return "[" + items.map(\.encoded).joined(separator: ",") + "]"
        case .object(let pairs):
            return "{" + pairs.map { JSON.quote($0.0) + ":" + $0.1.encoded }.joined(separator: ",") + "}"
        }
    }

    /// Like Python with ensure_ascii: control characters and anything past
    /// ASCII become \u escapes.
    static func quote(_ s: String) -> String {
        var out = "\""
        for unit in s.utf16 {
            switch unit {
            case 0x22: out += "\\\""
            case 0x5C: out += "\\\\"
            case 0x0A: out += "\\n"
            case 0x0D: out += "\\r"
            case 0x09: out += "\\t"
            case 0x08: out += "\\b"
            case 0x0C: out += "\\f"
            case 0x20..<0x7F: out.unicodeScalars.append(Unicode.Scalar(unit)!)
            default: out += String(format: "\\u%04x", unit)
            }
        }
        return out + "\""
    }
}
