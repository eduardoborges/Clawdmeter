import Foundation
import Testing
@testable import ClaudioCore

// The same cases as daemon/tests/test_attention.py.

private func tempDir() -> URL {
    let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

@Test func attentionFlag() throws {
    let dir = tempDir(), flag = dir.appending(path: "attention")
    #expect(Attention.take(in: dir) == nil)                                       // absent
    FileManager.default.createFile(atPath: flag.path, contents: nil)
    #expect(Attention.take(in: dir)?.message == "")                               // a bare touch still beeps
    #expect(!FileManager.default.fileExists(atPath: flag.path))                   // consumed
    try #"{"m": "Você  aprova\na ação?", "s": "abc"}"#.write(to: flag, atomically: true, encoding: .utf8)
    let alert = Attention.take(in: dir)
    #expect(alert?.message == "Voce aprova a acao?" && alert?.session == "abc")
    #expect(Attention.toASCII(String(repeating: "x", count: 200), 120) == String(repeating: "x", count: 117) + "...")
    FileManager.default.createFile(atPath: flag.path, contents: nil)
    try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-Attention.maxAge - 1)],
                                          ofItemAtPath: flag.path)
    #expect(Attention.take(in: dir) == nil)                                       // stale
    #expect(!FileManager.default.fileExists(atPath: flag.path))
}

@Test func clears() {
    let dir = tempDir()
    FileManager.default.createFile(atPath: dir.appending(path: "clear-abc").path, contents: nil)
    #expect(Set(Attention.takeClears(in: dir).keys) == ["abc"])
    #expect(Attention.takeClears(in: dir).isEmpty)                                // consumed
}

@Test func encodePayloadFits() {
    let base: [(String, JSON)] = [("s", .int(4)), ("ok", .bool(true)), ("b", .int(1))]
    func m(_ s: String) -> [(String, JSON)] { base + [("m", .string(s))] }
    func decoded(_ s: String) -> [String: Any] { try! JSONSerialization.jsonObject(with: Data(s.utf8)) as! [String: Any] }
    #expect(decoded(Attention.encode(m("hi"), limit: 180))["m"] as? String == "hi")
    let long = Attention.encode(m(String(repeating: "x", count: 200)), limit: 120)
    #expect(long.utf8.count <= 120 && (decoded(long)["m"] as! String).hasSuffix("..."))
    #expect(decoded(Attention.encode(m(String(repeating: "x", count: 200)), limit: 26))["m"] == nil)
}

extension Attention.Alert: Equatable {
    public static func == (a: Self, b: Self) -> Bool { a.message == b.message && a.session == b.session && a.time == b.time }
}
