import Foundation

/// Flashes a board from a firmware zip made by tools/package_firmware.py:
/// the images plus a manifest with the chip and each segment's offset. The
/// NVS partition isn't in the zip, so the BLE bond and saved settings survive.
public enum Firmware {
    public static let repo = "eduardoborges/tally"

    public struct Manifest: Decodable {
        public struct Segment: Decodable {
            public let offset: String
            public let file: String
        }
        public let env: String
        public let chip: String
        public let segments: [Segment]
    }

    public enum Failure: LocalizedError {
        case unreadable(String)
        case noEsptool
        case esptool(Int32)

        public var errorDescription: String? {
            switch self {
            case .unreadable(let why): "The firmware file can't be used: \(why)"
            case .noEsptool: "esptool isn't installed. Install it with `brew install esptool`."
            case .esptool(let code): "esptool stopped with code \(code). The log has the details."
            }
        }
    }

    /// The boards, by PlatformIO env, with the names people know them by.
    public static let boards: [(env: String, name: String)] = [
        ("waveshare_amoled_216", "AMOLED 2.16 (ESP32-S3)"),
        ("waveshare_amoled_18", "AMOLED 1.8 (ESP32-S3)"),
        ("waveshare_amoled_206", "AMOLED 2.06 (ESP32-S3)"),
        ("waveshare_amoled_216_c6", "AMOLED 2.16 (ESP32-C6)"),
        ("waveshare_amoled_18_c6", "AMOLED 1.8 (ESP32-C6)"),
        ("waveshare_lcd_154", "LCD 1.54 (ESP32-S3)"),
        ("waveshare_lcd_4", "LCD 4 (ESP32-S3)"),
    ]

    /// Serial ports that can be a board. The ESP32's USB port shows up as a
    /// usbmodem device.
    public static func ports() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? [])
            .filter { $0.hasPrefix("cu.usbmodem") }.sorted().map { "/dev/" + $0 }
    }

    /// Unzips a firmware zip into a temporary folder and reads its manifest.
    public static func open(zip: URL) throws -> (dir: URL, manifest: Manifest) {
        let dir = FileManager.default.temporaryDirectory.appending(path: "tally-firmware-\(UUID().uuidString)")
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", zip.path, dir.path]
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0 else { throw Failure.unreadable("it isn't a zip") }
        guard let data = try? Data(contentsOf: dir.appending(path: "manifest.json")),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else {
            throw Failure.unreadable("it has no manifest.json")
        }
        for s in manifest.segments where !FileManager.default.fileExists(atPath: dir.appending(path: s.file).path) {
            throw Failure.unreadable("\(s.file) is missing")
        }
        return (dir, manifest)
    }

    /// esptool from Homebrew or the PATH, else PlatformIO's copy.
    public static func esptool() -> (executable: URL, leading: [String])? {
        for path in ["/opt/homebrew/bin/esptool", "/usr/local/bin/esptool"]
        where FileManager.default.isExecutableFile(atPath: path) {
            return (URL(fileURLWithPath: path), [])
        }
        let pio = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".platformio")
        let python = pio.appending(path: "penv/bin/python"), script = pio.appending(path: "packages/tool-esptoolpy/esptool.py")
        if FileManager.default.isExecutableFile(atPath: python.path), FileManager.default.fileExists(atPath: script.path) {
            return (python, [script.path])
        }
        return nil
    }

    /// esptool's arguments: write every segment at its offset and keep the
    /// flash settings the bootloader was built with.
    public static func arguments(_ manifest: Manifest, in dir: URL, port: String) -> [String] {
        ["--chip", manifest.chip, "--port", port, "--baud", "921600", "--before", "default-reset",
         "--after", "hard-reset", "write-flash", "--flash-mode", "keep", "--flash-freq", "keep", "--flash-size", "keep"]
            + manifest.segments.flatMap { [$0.offset, dir.appending(path: $0.file).path] }
    }

    /// Flashes the zip to the board on `port`, refusing one built for another
    /// board than `env`. `progress` gets 0 to 1 across all segments, `output`
    /// every line esptool prints.
    public static func flash(zip: URL, port: String, env: String?, progress: @escaping @Sendable (Double) -> Void,
                             output: @escaping @Sendable (String) -> Void) async throws {
        let (dir, manifest) = try open(zip: zip)
        defer { try? FileManager.default.removeItem(at: dir) }
        if let env, manifest.env != env {
            throw Failure.unreadable("it's for \(boards.first { $0.env == manifest.env }?.name ?? manifest.env)")
        }
        guard let tool = esptool() else { throw Failure.noEsptool }
        let process = Process()
        process.executableURL = tool.executable
        process.arguments = tool.leading + arguments(manifest, in: dir, port: port)
        process.environment = ProcessInfo.processInfo.environment.merging(["PYTHONUNBUFFERED": "1"]) { $1 }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let tracker = ProgressTracker(segments: manifest.segments.count, progress: progress, output: output)
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { tracker.feed(String(decoding: data, as: UTF8.self)) }
        }
        try process.run()
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in done.resume() }
        }
        pipe.fileHandleForReading.readabilityHandler = nil
        guard process.terminationStatus == 0 else { throw Failure.esptool(process.terminationStatus) }
        progress(1)
    }

    /// The firmware zip for `env` in the latest GitHub release, if any.
    public static func latestRelease(env: String) async -> (version: String, url: URL)? {
        guard let (data, response) = try? await URLSession.shared.data(from: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let asset = (json["assets"] as? [[String: Any]])?.first(where: { $0["name"] as? String == "tally-firmware-\(env).zip" }),
              let link = (asset["browser_download_url"] as? String).flatMap(URL.init(string:)) else { return nil }
        return (tag, link)
    }

    /// Downloads a release zip to a temporary file.
    public static func download(_ url: URL) async throws -> URL {
        let (file, _) = try await URLSession.shared.download(from: url)
        let zip = FileManager.default.temporaryDirectory.appending(path: "tally-firmware-\(UUID().uuidString).zip")
        try FileManager.default.moveItem(at: file, to: zip)
        return zip
    }
}

/// Turns esptool's output into lines and an overall percentage. esptool
/// redraws its progress with carriage returns, so both end a line.
final class ProgressTracker: @unchecked Sendable {
    private let segments: Int
    private let progress: @Sendable (Double) -> Void
    private let output: @Sendable (String) -> Void
    private var buffer = ""
    private var written = 0
    private let lock = NSLock()

    init(segments: Int, progress: @escaping @Sendable (Double) -> Void, output: @escaping @Sendable (String) -> Void) {
        (self.segments, self.progress, self.output) = (max(segments, 1), progress, output)
    }

    func feed(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        buffer += text
        while let end = buffer.firstIndex(where: { $0 == "\n" || $0 == "\r" }) {
            // esptool 5 draws its progress bar with cursor codes even into a pipe.
            let line = buffer[..<end].replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[A-Za-z]", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            buffer.removeSubrange(...end)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("Wrote ") {
                written += 1
                progress(min(1, Double(written) / Double(segments)))
            } else if let pct = line.firstMatch(of: #/(\d+(?:\.\d+)?) ?%/#).flatMap({ Double($0.1) }) {
                progress(min(1, (Double(written) + pct / 100) / Double(segments)))
            }
            output(line)
        }
    }
}
