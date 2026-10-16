import SwiftUI
import TallyCore

/// The history tab: the display's Stats workspace, plus the busiest hour today.
struct ActivityView: View {
    let stats: Stats.Summary?
    let today: Today.Summary?

    var body: some View {
        if let stats {
            Platter {
                HStack(alignment: .firstTextBaseline) {
                    Text("Last 26 weeks").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    if let days = stats.values.first(where: { $0.0 == "Active days" }) {
                        Text("\(days.1) days").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Heatmap(stats: stats)
            }
            Block(title: "All time") {
                let shown = stats.values.filter { $0.0 != "Active days" }
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    ForEach(Array(stride(from: 0, to: shown.count, by: 3)), id: \.self) { i in
                        GridRow {
                            ForEach(i..<min(i + 3, shown.count), id: \.self) {
                                Figure(value: shown[$0].1, label: shown[$0].0.lowercased())
                            }
                        }
                    }
                }
            }
        } else {
            Platter { Empty(text: "No /stats history yet.") }
        }
        if let today, let peak = today.perHour.indices.max(by: { today.perHour[$0] < today.perHour[$1] }),
           today.perHour[peak] > 0 {
            Block(title: "Today") {
                HStack(spacing: 0) {
                    Figure(value: String(format: "%02d:00", peak), label: "busiest hour")
                    Figure(value: today.topProject, label: "top project")
                    Figure(value: "\(today.sessions)", label: "sessions")
                }
            }
        }
    }
}

/// 26 week columns of 7 days, Sunday on top, shaded by quarter of the active
/// days like the display draws it.
private struct Heatmap: View {
    let stats: Stats.Summary
    static let cell: CGFloat = 8.5
    static let gap: CGFloat = 2.5

    private func color(_ level: Int) -> Color {
        level == 0 ? Color.primary.opacity(0.08) : Theme.accent.opacity([0, 0.35, 0.55, 0.78, 1][level])
    }

    var body: some View {
        let weeks = (stats.levels.count + 6) / 7
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                ForEach(stats.months, id: \.1) { month in
                    Text(month.0).font(.caption2).foregroundStyle(.secondary)
                        .offset(x: CGFloat(month.1) * (Self.cell + Self.gap))
                }
            }
            .frame(height: 11, alignment: .topLeading)
            HStack(alignment: .top, spacing: Self.gap) {
                ForEach(0..<weeks, id: \.self) { week in
                    VStack(spacing: Self.gap) {
                        ForEach(0..<7, id: \.self) { day in
                            let i = week * 7 + day
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(i < stats.levels.count ? color(stats.levels[i]) : .clear)
                                .frame(width: Self.cell, height: Self.cell)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
