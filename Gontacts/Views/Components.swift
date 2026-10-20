import SwiftUI

extension EventKind {
    var tint: Color {
        switch self {
        case .birthday: .pink
        case .anniversary: .orange
        case .other: .teal
        }
    }
}

struct AvatarView: View {
    let contact: Contact
    var size: CGFloat = 44

    private static let palette: [Color] = [.indigo, .pink, .orange, .teal, .blue, .green]

    private var color: Color {
        let seed = contact.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return Self.palette[seed % Self.palette.count]
    }

    var body: some View {
        Group {
            if let url = contact.photoURL {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { initials }
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initials: some View {
        Circle().fill(color.opacity(0.22))
            .overlay { Text(contact.initials).font(.system(size: size * 0.38, weight: .semibold)).foregroundStyle(color) }
    }
}

/// Small icon + text line used under names in lists.
struct EventLine: View {
    let kind: EventKind
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: kind.symbol).foregroundStyle(kind.tint).frame(width: 18)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
    }
}

extension String {
    /// "mobile" becomes "Mobile", but names that already have capitals, like "WhatsApp", are left alone.
    var displayLabel: String { self == lowercased() ? capitalized : self }
}
