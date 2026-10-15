import Foundation
import TallyCore

@main
@MainActor
enum Main {
    static func main() {
        // `--dump ss|td|stats` prints messages the way the daemon builds them,
        // to compare the two.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--dump") {
            switch i + 1 < args.count ? args[i + 1] : "" {
            case "ss": print(Sessions.message().encoded)
            case "td": print(Today.message().encoded)
            case "stats": Stats.load().forEach { print($0.encoded) }
            default:
                FileHandle.standardError.write(Data("usage: Tally --dump ss|td|stats\n".utf8))
                exit(2)
            }
            return
        }
        TallyApp.main()
    }
}
