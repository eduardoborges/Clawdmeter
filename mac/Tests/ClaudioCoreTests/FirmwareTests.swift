import Foundation
import Testing
@testable import ClaudioCore

private final class Collected: @unchecked Sendable {
    var progress: [Double] = []
    var lines: [String] = []
}

@Test func progressFollowsEsptoolAcrossSegments() {
    let got = Collected()
    let tracker = ProgressTracker(segments: 2, progress: { got.progress.append($0) }, output: { got.lines.append($0) })
    tracker.feed("\u{1B}[KWriting at 0x00000000 [###   ]  50.0% 10/20 bytes... \u{1B}[F\r")
    tracker.feed("Wrote 20 bytes at 0x00000000\nWriting at 0x00010000 (25 %)\nHash of data verified.\n")
    #expect(got.lines == ["Writing at 0x00000000 [###   ]  50.0% 10/20 bytes...", "Wrote 20 bytes at 0x00000000",
                          "Writing at 0x00010000 (25 %)", "Hash of data verified."])
    #expect(got.progress == [0.25, 0.5, 0.625])
}

@Test func argumentsWriteEverySegmentAtItsOffset() throws {
    let manifest = try JSONDecoder().decode(Firmware.Manifest.self, from: Data(#"""
        {"env": "waveshare_amoled_216", "chip": "esp32s3",
         "segments": [{"offset": "0x0", "file": "bootloader.bin"}, {"offset": "0x10000", "file": "firmware.bin"}]}
        """#.utf8))
    let args = Firmware.arguments(manifest, in: URL(fileURLWithPath: "/fw"), port: "/dev/cu.usbmodem1")
    #expect(args.prefix(4) == ["--chip", "esp32s3", "--port", "/dev/cu.usbmodem1"])
    #expect(args.suffix(4) == ["0x0", "/fw/bootloader.bin", "0x10000", "/fw/firmware.bin"])
}

@Test func openReadsTheManifestAndRefusesBrokenZips() throws {
    let src = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
    try #"{"env": "waveshare_amoled_216", "chip": "esp32s3", "segments": [{"offset": "0x0", "file": "a.bin"}]}"#
        .write(to: src.appending(path: "manifest.json"), atomically: true, encoding: .utf8)
    func zip(_ name: String) throws -> URL {
        let out = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-\(name).zip")
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-c", "-k", src.path, out.path]
        try ditto.run()
        ditto.waitUntilExit()
        return out
    }
    #expect(throws: Firmware.Failure.self) { try Firmware.open(zip: try zip("missing-bin")) }   // a.bin isn't there
    try Data([1, 2, 3]).write(to: src.appending(path: "a.bin"))
    let (dir, manifest) = try Firmware.open(zip: try zip("ok"))
    #expect(manifest.chip == "esp32s3" && manifest.segments.map(\.file) == ["a.bin"])
    #expect(FileManager.default.fileExists(atPath: dir.appending(path: "a.bin").path))
}
