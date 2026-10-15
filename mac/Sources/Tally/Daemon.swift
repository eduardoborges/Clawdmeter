import Foundation
import Observation
import TallyCore

/// The Python daemon's loop: every 5 seconds, poll usage once a minute (right
/// away for an alert, its clear or a refresh request from the device) and keep
/// the Sessions, Today and Stats workspaces current.
@MainActor
@Observable
final class Daemon {
    static let tick = 5.0
    static let pollInterval = 60.0
    static let todayInterval = 60.0

    private(set) var lastUpdate: Date?

    @ObservationIgnored private let link: DeviceLink
    @ObservationIgnored private let selector = PlanSelector()
    @ObservationIgnored private var running = false
    @ObservationIgnored private var refreshRequested = false
    // Reset on every connect.
    @ObservationIgnored private var lastPoll = 0.0
    @ObservationIgnored private var usedSuccessfully = false
    @ObservationIgnored private var alert: Attention.Alert?
    @ObservationIgnored private var alertUnsent = false
    @ObservationIgnored private var clearUnsent = false
    @ObservationIgnored private var statsSent: Date?
    @ObservationIgnored private var sessionsSent: String?
    @ObservationIgnored private var todaySig: String?
    @ObservationIgnored private var todaySent: String?
    @ObservationIgnored private var todayChecked = 0.0

    init(link: DeviceLink) {
        self.link = link
        link.onReady = { [weak self] in self?.connected() }
        link.onRefresh = { [weak self] in
            self?.refreshRequested = true
            self?.tick()
        }
        Timer.scheduledTimer(withTimeInterval: Self.tick, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func connected() {
        // An alert written while the device was away shouldn't beep now.
        try? FileManager.default.removeItem(at: Attention.directory.appending(path: "attention"))
        _ = Attention.takeClears()
        lastPoll = 0
        usedSuccessfully = false
        alert = nil
        alertUnsent = false
        clearUnsent = false
        statsSent = nil
        sessionsSent = nil
        todaySig = nil
        todaySent = nil
        todayChecked = 0
        tick()
    }

    func tick() {
        guard link.isReady, !running else { return }
        running = true
        Task {
            await run()
            running = false
        }
    }

    private func run() async {
        let now = Date().timeIntervalSince1970
        // One alert slot, latest wins. A session still waiting can notify twice
        // (AskUserQuestion, then a permission prompt): keep the first and beep once.
        if let new = Attention.take(), !(alert.map { !$0.session.isEmpty && $0.session == new.session } ?? false) {
            alert = new
            alertUnsent = true
            clearUnsent = false
        }
        if let current = alert, (Attention.takeClears()[current.session] ?? 0) > current.time {
            clearUnsent = !alertUnsent   // never shown, nothing to clear
            alert = nil
            alertUnsent = false
        }

        // The firmware treats every write as a full reading, so alerts and clears
        // ride on a fresh poll.
        if alertUnsent || clearUnsent || refreshRequested || now - lastPoll >= Self.pollInterval {
            refreshRequested = false
            let config = Config()
            let (payload, dead) = await Usage.pollActive(dirs: Credentials.configDirs(config), selector: selector)
            var extra: [(String, JSON)] = []
            if alertUnsent, let alert {
                if config.choice("beep", ["off", "on"], default: "off") == "on" { extra.append(("b", .int(1))) }
                if !alert.message.isEmpty { extra.append(("m", .string(alert.message))) }
            }
            if clearUnsent { extra.append(("x", .int(1))) }
            if let payload {
                if await write(.object(payload + extra)) {
                    lastPoll = Date().timeIntervalSince1970
                    usedSuccessfully = true
                    alertUnsent = false
                    clearUnsent = false
                }
            } else if dead {
                // No live token anywhere: show "No data" instead of stale numbers
                // until Claude Code renews it.
                log("No usable token; run `claude login` or use Claude Code to renew it")
                if await write(.object([("ok", .bool(false))] + extra)) {
                    lastPoll = Date().timeIntervalSince1970
                    alertUnsent = false
                    clearUnsent = false
                }
            } else {
                log("No usable config dir this cycle")
            }
        }
        guard link.takesStats && usedSuccessfully else { return }

        // Stats: resend whenever Claude Code rewrites its cache.
        let statsMtime = try? Stats.cache.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        if let statsMtime, statsMtime != statsSent {
            var sent = true
            for message in Stats.load() { sent = await write(message) && sent }
            if sent { statsSent = statsMtime }
        }

        // Sessions: resend when a session or its age in minutes changes.
        let sessions = Sessions.message().encoded
        if sessions != sessionsSent, await write(raw: sessions) { sessionsSent = sessions }

        // Today: scanning the transcripts takes a moment, so check once a
        // minute, off the main thread, and only when something changed.
        if now - todayChecked >= Self.todayInterval {
            todayChecked = now
            let sig = await Task.detached { Today.signature() }.value
            if sig != todaySig {
                let today = await Task.detached { Today.message().encoded }.value
                var done = today == todaySent
                if !done { done = await write(raw: today) }
                if done {
                    todaySig = sig
                    todaySent = today
                }
            }
        }
    }

    /// Sends one message, shortening an alert message to fit like the daemon.
    private func write(_ message: JSON) async -> Bool {
        guard case .object(let pairs) = message else { return await write(raw: message.encoded) }
        return await write(raw: Attention.encode(pairs, limit: link.maxWrite > 0 ? link.maxWrite : 180))
    }

    private func write(raw message: String) async -> Bool {
        log("Sending: \(message)")
        guard link.send(Data(message.utf8)) else {
            log("Write failed")
            return false
        }
        lastUpdate = .now
        return true
    }
}
