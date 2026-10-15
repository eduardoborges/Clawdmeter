import Foundation
import TallyCore

@main
@MainActor
enum Main {
    static func main() {
        // `--dump ss|stats` prints messages the way the daemon builds them,
        // to compare the two.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--dump") {
            switch i + 1 < args.count ? args[i + 1] : "" {
            case "ss": print(Sessions.message().encoded)
            case "stats": Stats.load().forEach { print($0.encoded) }
            default:
                FileHandle.standardError.write(Data("usage: Tally --dump ss|stats\n".utf8))
                exit(2)
            }
            return
        }
        TallyApp.main()
    }
}
