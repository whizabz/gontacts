import SwiftUI
import WidgetKit

/// The medium "spotlight": today's celebration (or the next one) large, with the one after it underneath.
struct SpotlightRoot: View {
    let entry: CelebrationEntry

    var body: some View {
        let hero = entry.todayRows.first ?? entry.upcomingRows.first
        Group {
            if let hero {
                Spotlight(entry: entry, hero: hero).widgetURL(hero.url)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "birthday.cake").font(.system(size: 28)).foregroundStyle(Theme.accent)
                    Text("No celebrations coming up").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .containerBackground(for: .widget) {
            WidgetBackground(confetti: hero == nil ? .none : (entry.days(until: hero!) == 0 ? .rich : .light))
        }
    }
}

private struct Spotlight: View {
    let entry: CelebrationEntry
    let hero: CelebrationRow

    var body: some View {
        let isToday = entry.days(until: hero) == 0
        let following = entry.rows.first { $0.id != hero.id }
        HStack(spacing: 16) {
            AvatarCircle(row: hero, size: 76, ring: isToday)
            VStack(alignment: .leading, spacing: 0) {
                Text(isToday ? "Today" : "Next up · \(entry.when(hero).lowercased())")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accent)
                Text(hero.name).font(.system(size: 22, weight: .bold)).lineLimit(2).minimumScaleFactor(0.8).padding(.top, 2)
                Text(hero.long).font(.system(size: 13)).foregroundStyle(Theme.secondary).lineLimit(1).padding(.top, 3)
                if let following {
                    Rectangle().fill(Theme.line).frame(height: 1).padding(.top, 10).padding(.bottom, 8)
                    (Text("Next · ").foregroundStyle(Theme.secondary)
                     + Text(following.name).fontWeight(.semibold)
                     + Text(", \(following.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))").foregroundStyle(Theme.secondary))
                        .font(.system(size: 12)).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
