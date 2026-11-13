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
            if let url = contact.photoURL, let image = SampleData.image(for: url) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let url = contact.photoURL {
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

extension View {
    /// The system draws a soft shadow under `.glass` buttons but not `.glassProminent` ones, so a
    /// primary button next to a secondary one looks flat. This gives it the same lift.
    func prominentButtonShadow() -> some View {
        shadow(color: .black.opacity(0.18), radius: 10, y: 5)
    }
}


/// Copy-to-clipboard button for contact details, in the same glass style as the other buttons;
/// flips to a checkmark briefly after copying.
struct CopyButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = text
            copied = true
            Task { try? await Task.sleep(for: .seconds(1.2)); copied = false }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(copied ? Color.green : Color.secondary)
                .frame(width: 32, height: 32)
                .contentShape(.rect)
        }
        // Just a grey icon, no button background, so a column of them stays quiet.
        .buttonStyle(.borderless)
        .sensoryFeedback(.success, trigger: copied) { _, new in new }
        .accessibilityLabel(copied ? "Copied" : "Copy")
    }
}
