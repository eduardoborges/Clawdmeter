import Foundation

private let logFile = FileManager.default.homeDirectoryForCurrentUser
    .appending(path: "Library/Logs/Clawdmeter.log")
private let stamp: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f
}()

/// Appends a timestamped line to ~/Library/Logs/Clawdmeter.log.
func log(_ message: String) {
    let line = Data("[\(stamp.string(from: .now))] \(message)\n".utf8)
    if let handle = try? FileHandle(forWritingTo: logFile) {
        handle.seekToEndOfFile()
        handle.write(line)
        try? handle.close()
    } else {
        try? line.write(to: logFile)
    }
}
