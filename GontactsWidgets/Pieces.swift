import SwiftUI
import UIKit

/// A photo when one has been saved for the contact, otherwise tinted initials (as in the app).
struct AvatarCircle: View {
    let row: CelebrationRow
    var size: CGFloat
    var ring = false

    var body: some View {
        let color = Theme.palette[row.seed % Theme.palette.count]
        Group {
            if let path = row.photoPath, let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image).resizable().widgetAccentedRenderingMode(.desaturated).scaledToFill()
            } else {
                Circle().fill(color.opacity(0.16))
                    .overlay { Text(row.initials).font(.system(size: size * 0.37, weight: .semibold)).foregroundStyle(color) }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay { if ring { Circle().strokeBorder(Theme.accent, lineWidth: 2.5).padding(-4.5) } }
        .padding(ring ? 4.5 : 0)
    }
}

/// "Today", as a solid pill in the full-colour widget. The clear and tinted looks turn every fill white, which
/// would hide the text, so there it is an outline with the text drawn over it.
struct TodayPill: View {
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        let label = Text("Today").font(.system(size: 12, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 4)
        if mode == .fullColor {
            label.foregroundStyle(Theme.accentOnAccent).background(Theme.accent, in: Capsule())
        } else {
            label.foregroundStyle(.primary).background { Capsule().strokeBorder(.primary, lineWidth: 1.5) }
        }
    }
}

struct DateTile: View {
    let date: Date
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(date.formatted(.dateTime.day())).font(.system(size: 17, weight: .bold))
            Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(Theme.secondary)
        }
    }
}

struct KindLine: View {
    let row: CelebrationRow
    var text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: row.symbol).font(.system(size: 10, weight: .semibold)).foregroundStyle(row.symbolColor)
            Text(text).font(.system(size: 12)).foregroundStyle(Theme.secondary).lineLimit(1)
        }
    }
}

struct Eyebrow: View {
    var text: String
    var symbol: String? = "birthday.cake"
    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.system(size: 12, weight: .semibold)) }
            Text(text).font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Theme.accent)
    }
}

/// The card behind every widget: a flat surface with a soft inner edge, and optional confetti.
struct WidgetBackground: View {
    var confetti: ConfettiLayer.Density
    var body: some View {
        ZStack {
            Theme.card
            if confetti != .none { ConfettiLayer(density: confetti) }
            ContainerRelativeShape().strokeBorder(Theme.edge, lineWidth: 1)
        }
    }
}
