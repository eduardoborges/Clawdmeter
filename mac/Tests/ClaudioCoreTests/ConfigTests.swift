import Foundation
import Testing
@testable import ClaudioCore

@Test func configSkipsCommentsAndTakesTheFirstValidValue() throws {
    let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try """
    # clock = 24
    Clock = sometimes
    clock = AUTO   # inline comment
    clock = 12
    beep=on
    """.write(to: file, atomically: true, encoding: .utf8)
    let config = Config(file: file)
    #expect(config.choice("clock", ["off", "auto", "12", "24"], default: "off") == "auto")
    #expect(config.choice("beep", ["off", "on"], default: "off") == "on")
    #expect(config.choice("chime", ["off", "on"], default: "off") == "off")
    #expect(Config(file: file.appending(path: "missing")).pairs.isEmpty)
}

@Test func configSetKeepsCommentsAndLeavesOneLine() throws {
    let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "config")
    try Config.set("beep", "on", in: file)                       // creates the folder and the file
    #expect(try String(contentsOf: file, encoding: .utf8) == "beep = on\n")
    try "# Claudio config\nclock = 24  # ok\nbeep=off\nBEEP = on\n".write(to: file, atomically: true, encoding: .utf8)
    try Config.set("beep", "on", in: file)
    try Config.set("done_after", "10", in: file)
    #expect(try String(contentsOf: file, encoding: .utf8) == "# Claudio config\nclock = 24  # ok\nbeep = on\ndone_after = 10\n")
    #expect(Config(file: file).choice("beep", ["off", "on"], default: "off") == "on")
}
