import SwiftUI
import WidgetKit

/// Picks the layout for each widget size and draws the card behind it.
struct CelebrationsRoot: View {
    let entry: CelebrationEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockRectangular(entry: entry).containerBackground(.clear, for: .widget)
        case .accessoryInline:
            LockInline(entry: entry).containerBackground(.clear, for: .widget)
        case .systemMedium:
            MediumList(entry: entry).containerBackground(for: .widget) { WidgetBackground(confetti: entry.rows.isEmpty ? .none : .light) }
        case .systemLarge:
            LargeList(entry: entry).containerBackground(for: .widget) { WidgetBackground(confetti: entry.rows.isEmpty ? .none : .light) }
        default:
            SmallView(entry: entry).containerBackground(for: .widget) { WidgetBackground(confetti: smallConfetti) }
        }
    }

    private var smallConfetti: ConfettiLayer.Density {
        if !entry.todayRows.isEmpty { return .rich }
        return entry.rows.isEmpty ? .none : .light
    }
}

// MARK: - Small

private struct SmallView: View {
    let entry: CelebrationEntry

    var body: some View {
        let today = entry.todayRows
        Group {
            if today.count >= 2 {
                SeveralToday(rows: today)
            } else if let one = today.first {
                TodayOne(row: one).widgetURL(one.url)
            } else if let next = entry.upcomingRows.first {
                NextUp(entry: entry, row: next).widgetURL(next.url)
            } else {
                EmptyState()
            }
        }
    }
}

private struct TodayOne: View {
    let row: CelebrationRow
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Today", symbol: row.symbol)
            Spacer(minLength: 4)
            AvatarCircle(row: row, size: 52, ring: true)
            Text(row.name).font(.system(size: 17, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.85).padding(.top, 10)
            Text(row.short).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.accent).padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SeveralToday: View {
    let rows: [CelebrationRow]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Today · \(rows.count)")
            Spacer(minLength: 4)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows.prefix(3)) { r in
                    HStack(spacing: 8) {
                        AvatarCircle(row: r, size: 26)
                        Text(r.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    }
                }
                if rows.count > 3 {
                    Text("+\(rows.count - 3) more").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NextUp: View {
    let entry: CelebrationEntry
    let row: CelebrationRow
    var body: some View {
        let days = entry.days(until: row)
        VStack(alignment: .leading, spacing: 0) {
            Text("Next up").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(days)").font(.system(size: 46, weight: .bold)).foregroundStyle(Theme.accent)
                Text(days == 1 ? "day" : "days").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.secondary)
            }
            .padding(.top, 4)
            Spacer(minLength: 4)
            HStack(spacing: 9) {
                AvatarCircle(row: row, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.name).font(.system(size: 13, weight: .semibold)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    Text(row.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .font(.system(size: 12)).foregroundStyle(Theme.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "birthday.cake").font(.system(size: 26)).foregroundStyle(Theme.accent)
            Text("No celebrations coming up").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Rows shared by medium and large

private struct ListRow: View {
    let entry: CelebrationEntry
    let row: CelebrationRow
    var avatar: CGFloat = 30
    var detail: String? = nil

    var body: some View {
        let isToday = entry.days(until: row) == 0
        Link(destination: row.url) {
            HStack(spacing: 10) {
                AvatarCircle(row: row, size: avatar)
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    KindLine(row: row, text: detail ?? (isToday ? row.short : row.long.components(separatedBy: " · ").first ?? row.long))
                }
                Spacer(minLength: 6)
                if isToday {
                    TodayPill()
                } else {
                    DateTile(date: row.date)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Medium

private struct MediumList: View {
    let entry: CelebrationEntry
    var body: some View {
        let rows = Array(entry.rows.prefix(3))
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Celebrations").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accent)
                Spacer()
                Text("Next 2 weeks").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.secondary)
            }
            if rows.isEmpty {
                EmptyState()
            } else {
                ForEach(rows) { ListRow(entry: entry, row: $0, avatar: 28) }
            }
        }
    }
}

// MARK: - Large

private struct LargeList: View {
    let entry: CelebrationEntry

    private struct Group: Identifiable { let id: String; let title: String; let rows: [CelebrationRow] }

    private var groups: [Group] {
        let rows = Array(entry.rows.prefix(5))
        let today = rows.filter { entry.days(until: $0) == 0 }
        let tomorrow = rows.filter { entry.days(until: $0) == 1 }
        let week = rows.filter { (2...7).contains(entry.days(until: $0)) }
        let later = rows.filter { entry.days(until: $0) > 7 }
        return [Group(id: "t", title: "Today", rows: today), Group(id: "m", title: "Tomorrow", rows: tomorrow),
                Group(id: "w", title: "This week", rows: week), Group(id: "l", title: "Coming up", rows: later)]
            .filter { !$0.rows.isEmpty }
    }

    var body: some View {
        let soon = entry.rows.filter { entry.days(until: $0) <= 7 }.count
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Celebrations").font(.system(size: 17, weight: .bold))
                Spacer()
                Text(soon == 0 ? "Nothing this week" : "\(soon) this week").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.secondary)
            }
            if entry.rows.isEmpty {
                EmptyState()
            } else {
                ForEach(groups) { g in
                    Text(g.title.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.6)
                        .foregroundStyle(Theme.secondary).padding(.top, 10).padding(.bottom, 2)
                    ForEach(g.rows) { ListRow(entry: entry, row: $0, avatar: g.id == "t" ? 34 : 30, detail: g.id == "t" ? $0.long : nil).frame(height: g.id == "t" ? 48 : 40) }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Lock screen

private struct LockRectangular: View {
    let entry: CelebrationEntry
    var body: some View {
        if let row = entry.todayRows.first ?? entry.upcomingRows.first {
            let isToday = entry.days(until: row) == 0
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: row.symbol).font(.system(size: 11, weight: .semibold))
                    Text(isToday ? "Today" : entry.when(row)).font(.system(size: 12, weight: .semibold))
                }
                Text(row.name).font(.system(size: 16, weight: .bold)).lineLimit(1)
                Text(rest(row)).font(.system(size: 12)).lineLimit(1).opacity(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(row.url)
        } else {
            Text("No celebrations coming up").font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func rest(_ row: CelebrationRow) -> String {
        let next = entry.rows.first { $0.id != row.id }
        let base = row.short
        guard let next else { return base }
        return "\(base) · Next: \(next.name.components(separatedBy: " ").first ?? next.name)"
    }
}

private struct LockInline: View {
    let entry: CelebrationEntry
    var body: some View {
        if let row = entry.todayRows.first ?? entry.upcomingRows.first {
            Label("\(row.name) · \(entry.when(row))", systemImage: row.symbol).widgetURL(row.url)
        } else {
            Label("No celebrations", systemImage: "birthday.cake")
        }
    }
}
