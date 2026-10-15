import Foundation
import Testing
@testable import ClawdmeterCore

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
