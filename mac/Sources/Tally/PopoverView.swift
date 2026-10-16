import Charts
import SwiftUI
import TallyCore

/// The panel that opens from the menu bar. It mirrors the display: the same
/// palette, the same usage bars and Claude Code's own spinner on the sessions.
struct PopoverView: View {
    enum Tab: String, CaseIterable { case now = "Now", activity = "Activity" }

    let dashboard: Dashboard
    let linkStatus: String
    let connected: Bool
    var onSettings: (() -> Void)?
    var onQuit: () -> Void = {}
    @State var tab = Tab.now

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            GlassTabs(tabs: Tab.allCases, selection: $tab)
            switch tab {
            case .now:
                UsagePanel(usage: dashboard.usage, noToken: dashboard.noToken)
                SessionsPanel(sessions: dashboard.sessions)
                TodayPanel(today: dashboard.today)
            case .activity:
                ActivityView(stats: dashboard.stats, today: dashboard.today)
            }
            footer
        }
        .padding(16)
        .frame(width: 340)
        .panelBackground()
        .foregroundStyle(Theme.text)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Tally").font(.system(size: 15, weight: .semibold))
            Text(connected ? "Display connected" : linkStatus).font(.system(size: 11))
                .foregroundStyle(connected ? Theme.dim : Theme.accent)
            Spacer()
            if let plan = dashboard.usage?.plan {
                Text(plan)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Theme.badge))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            if let updated = dashboard.updated {
                Text("updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.faint)
            }
            Spacer()
            if let onSettings { Button("Settings…", action: onSettings).glassAction() }
            Button("Quit", action: onQuit).glassAction()
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.dim)
    }
}

/// A flat panel with a hairline border, like the display's cards.
struct Panel<Content: View>: View {
    var title: String?
    var detail: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.dim)
                    Spacer()
                    if let detail { Text(detail).font(Theme.mono).foregroundStyle(Theme.faint) }
                }
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
    }
}

/// A titled block with no box, set off from the one above by a hairline.
/// Only the usage meters get a panel; everything else reads as a list.
struct Block<Content: View>: View {
    var title: String
    var detail: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.dim)
                Spacer()
                if let detail { Text(detail).font(Theme.mono).foregroundStyle(Theme.faint) }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Usage

private struct UsagePanel: View {
    let usage: Dashboard.Usage?
    let noToken: Bool

    var body: some View {
        if let usage {
            HStack(spacing: 10) {
                if usage.enterprise {
                    UsageBar(label: "Spend", pct: usage.session, note: "resets \(usage.resetsOn ?? "monthly")")
                    UsageBar(label: "Period", pct: usage.periodElapsed ?? 0, note: "of the month gone")
                } else {
                    UsageBar(label: "5-hour", pct: usage.session, note: "resets in \(duration(usage.sessionReset))")
                    UsageBar(label: "Weekly", pct: usage.weekly, note: "resets in \(duration(usage.weeklyReset))")
                }
            }
        } else if noToken {
            Panel { Empty(text: "No Claude Code login found. Run claude to sign in.") }
        } else {
            HStack(spacing: 10) {
                UsageBar(label: "5-hour", pct: nil, note: "waiting for a reading")
                UsageBar(label: "Weekly", pct: nil, note: "waiting for a reading")
            }
        }
    }
}

/// The display's usage panel: the percentage, a bar and when it resets.
private struct UsageBar: View {
    let label: String
    let pct: Int?   // nil draws the panel's shape while the first reading loads
    let note: String

    var body: some View {
        Panel {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                if let pct {
                    Text("\(pct)").font(.system(size: 30, weight: .semibold)).monospacedDigit()
                    Text("%").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.dim)
                } else {
                    RoundedRectangle(cornerRadius: 3).fill(Theme.track).frame(width: 52, height: 26)
                        .padding(.vertical, 5)
                }
                Spacer()
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dim)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule().fill(Theme.bar(pct ?? 0))
                        .frame(width: geo.size.width * CGFloat(min(max(pct ?? 0, 0), 100)) / 100)
                }
            }
            .frame(height: 5)
            Text(note).font(Theme.mono).foregroundStyle(Theme.faint)
        }
        .animation(.easeOut(duration: 0.4), value: pct)
    }
}

// MARK: Sessions

private struct SessionsPanel: View {
    let sessions: [Sessions.Session]
    static let shown = 5

    private var detail: String? {
        let waiting = sessions.filter { $0.state == "a" }.count
        let working = sessions.filter { $0.state == "w" }.count
        let parts = [waiting > 0 ? "\(waiting) waiting" : nil, working > 0 ? "\(working) working" : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    var body: some View {
        Block(title: "Sessions", detail: detail) {
            if sessions.isEmpty {
                Empty(text: "No open Claude Code sessions.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sessions.prefix(Self.shown).enumerated()), id: \.element.id) { i, session in
                        if i > 0 { Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 20) }
                        SessionRow(session: session).padding(.vertical, 7)
                    }
                    if sessions.count > Self.shown {
                        Text("+\(sessions.count - Self.shown) more").font(Theme.mono).foregroundStyle(Theme.faint)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 20).padding(.top, 4)
                    }
                }
            }
        }
    }
}

/// Claude Code's spinner: turning while a session works, pulsing when it
/// needs you, a dot when it's done. The display draws the same marks.
private struct SessionMark: View {
    let state: String
    static let frames = ["·", "✢", "✳", "✶", "✻", "✽"]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.12)) { context in
            // With Reduce Motion on, the marks hold still on their middle frame.
            let step = reduceMotion ? 3 : Int(context.date.timeIntervalSinceReferenceDate / 0.12)
            switch state {
            case "w":
                let phase = step % 10   // up the frames and back down
                Text(Self.frames[phase < 6 ? phase : 10 - phase]).foregroundStyle(Theme.accent)
            case "a":
                Text("✶").foregroundStyle(Theme.accent).opacity(step / 5 % 2 == 0 ? 1 : 0.35)
            default:
                Text("·").foregroundStyle(Theme.faint)
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .frame(width: 14)
    }
}

private struct SessionRow: View {
    let session: Sessions.Session

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            SessionMark(state: session.state)
            VStack(alignment: .leading, spacing: 3) {
                (Text(session.project).fontWeight(.semibold)
                    + Text(session.title.isEmpty ? "" : "  \(session.title)").foregroundColor(Theme.dim))
                    .font(.system(size: 13))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !session.doing.isEmpty {
                        Text(session.doing).foregroundStyle(session.state == "a" ? Theme.accent : Theme.dim)
                    }
                    if !session.branch.isEmpty { Text(session.branch).foregroundStyle(Theme.faint) }
                }
                .font(Theme.mono)
                .lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(duration(session.minutes, ago: session.state == "d")).font(Theme.mono).foregroundStyle(Theme.faint)
        }
        .opacity(session.state == "d" ? 0.65 : 1)
    }
}

// MARK: Today

private struct TodayPanel: View {
    let today: Today.Summary?

    var body: some View {
        Block(title: "Today", detail: today.map { "\(Stats.grouped($0.prompts)) prompts" }) {
            if let today {
                Chart {
                    ForEach(Array(today.perHour.enumerated()), id: \.offset) { hour, count in
                        BarMark(x: .value("Hour", hour), y: .value("Messages", count), width: 6)
                            .foregroundStyle(Theme.accent)
                            .cornerRadius(1)
                    }
                }
                .chartXScale(domain: -0.5...23.5)
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18]) { value in
                        AxisValueLabel {
                            Text(String(format: "%02d", value.as(Int.self) ?? 0))
                                .font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.faint)
                        }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 56)
                HStack(spacing: 0) {
                    Figure(value: Stats.human(today.tokens), label: "tokens")
                    Figure(value: Stats.grouped(today.toolCalls), label: "tool calls")
                    Figure(value: "\(today.activeHours)h", label: "active")
                }
            } else {
                Empty(text: "Counting today's messages.")
            }
        }
    }
}

struct Figure: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: 15, weight: .semibold)).monospacedDigit()
            Text(label).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Empty: View {
    let text: String

    var body: some View {
        Text(text).font(.system(size: 12)).foregroundStyle(Theme.faint)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
    }
}
