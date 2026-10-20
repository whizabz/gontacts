import SwiftUI
import UIKit

/// Messaging apps that can open a conversation from a phone number.
/// Nothing is sent from here: the app opens on that contact and you paste and edit the message there.
enum MessagingApp: String, CaseIterable, Identifiable {
    case messages, whatsapp, telegram, signal

    var id: String { rawValue }

    var name: String {
        switch self {
        case .messages: "Messages"
        case .whatsapp: "WhatsApp"
        case .telegram: "Telegram"
        case .signal: "Signal"
        }
    }

    var symbol: String {
        switch self {
        case .messages: "message.fill"
        case .whatsapp: "phone.bubble.fill"
        case .telegram: "paperplane.fill"
        case .signal: "bubble.left.and.bubble.right.fill"
        }
    }

    var tint: Color {
        switch self {
        case .messages: .green
        case .whatsapp: .teal
        case .telegram: .blue
        case .signal: .indigo
        }
    }

    /// Whether the app is installed. Messages is always there; the others need their scheme listed in LSApplicationQueriesSchemes.
    @MainActor var isInstalled: Bool {
        let probe: String
        switch self {
        case .messages: return true
        case .whatsapp: probe = "whatsapp://"
        case .telegram: probe = "tg://"
        case .signal: probe = "sgnl://"
        }
        return URL(string: probe).map { UIApplication.shared.canOpenURL($0) } ?? false
    }

    /// Deep link to the conversation with `phone` (digits, with a leading + when it has a country code).
    func url(forPhone phone: String) -> URL? {
        let digits = phone.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        switch self {
        case .messages: return URL(string: "sms:\(phone)")
        case .whatsapp: return URL(string: "whatsapp://send?phone=\(digits)")
        case .telegram: return URL(string: "tg://resolve?phone=\(digits)")
        case .signal: return URL(string: "https://signal.me/#p/+\(digits)")
        }
    }
}

struct WishView: View {
    let contact: Contact
    let occurrence: EventOccurrence?

    enum Tone: String, CaseIterable, Identifiable {
        case warm = "Warm", playful = "Playful", short = "Short"
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var tone: Tone = .warm
    @State private var text = ""
    @State private var copied = false

    private var firstName: String { contact.givenName.isEmpty ? contact.displayName : contact.givenName }

    private var phone: String {
        let raw = contact.phones.first(where: { $0.label == "mobile" })?.value ?? contact.phones.first?.value ?? ""
        return raw.filter { $0.isNumber || $0 == "+" }
    }

    private var apps: [MessagingApp] { MessagingApp.allCases.filter(\.isInstalled) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        AvatarView(contact: contact, size: 44)
                        VStack(alignment: .leading) {
                            Text("Wish \(firstName)").font(.headline)
                            if let occurrence { EventLine(kind: occurrence.event.kind, text: occurrence.detail) }
                        }
                        Spacer()
                    }

                    Picker("Tone", selection: $tone) {
                        ForEach(Tone.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .trailing, spacing: 10) {
                        TextEditor(text: $text)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 150)
                        Button {
                            UIPasteboard.general.string = text
                            withAnimation { copied = true }
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                withAnimation { copied = false }
                            }
                        } label: {
                            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .contentTransition(.symbolEffect(.replace))
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.regular)
                        .sensoryFeedback(.success, trigger: copied) { _, new in new }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))

                    Text("Edit the message, tap Copy, then open the conversation below and paste it. Nothing is sent from Gontacts.")
                        .font(.footnote).foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wish using").font(.headline)
                        if phone.isEmpty {
                            Text("\(firstName) has no phone number saved, so there's no conversation to open.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                                    if index > 0 { Divider().padding(.leading, 56) }
                                    Button {
                                        if let url = app.url(forPhone: phone) { openURL(url) }
                                    } label: {
                                        HStack(spacing: 14) {
                                            Image(systemName: app.symbol)
                                                .foregroundStyle(app.tint)
                                                .frame(width: 32, height: 32)
                                                .background(app.tint.opacity(0.15), in: .rect(cornerRadius: 9))
                                            Text(app.name).foregroundStyle(.primary)
                                            Spacer()
                                            Image(systemName: "arrow.up.right").font(.footnote).foregroundStyle(.tertiary)
                                        }
                                        .padding(.vertical, 10)
                                        .contentShape(.rect)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14)
                            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() } }
            }
        }
        .presentationDetents([.large])
        .onAppear { text = draft(for: tone) }
        .onChange(of: tone) { _, new in text = draft(for: new) }
    }

    private func draft(for tone: Tone) -> String {
        let kind = occurrence?.event.kind ?? .birthday
        let years = occurrence?.years
        let n = firstName
        switch (kind, tone) {
        case (.birthday, .warm):
            return years.map { "Happy birthday, \(n)! Wishing you a wonderful \(ordinal($0)) year, with plenty of good coffee, good work and good people around you. Let's catch up soon." }
                ?? "Happy birthday, \(n)! Wishing you a wonderful year ahead, with plenty of good coffee, good work and good people around you. Let's catch up soon."
        case (.birthday, .playful):
            return "Happy birthday, \(n)! Another trip around the sun, and you're still the best part of my contacts list."
        case (.birthday, .short):
            return "Happy birthday, \(n)!"
        case (.anniversary, .warm):
            return years.map { "Happy anniversary, \(n)! \($0) \($0 == 1 ? "year" : "years") is something to celebrate. Wishing you both many more." }
                ?? "Happy anniversary, \(n)! Wishing you both many more happy years."
        case (.anniversary, .playful):
            return "Happy anniversary, \(n)! Still putting up with each other. Respect."
        case (.anniversary, .short):
            return "Happy anniversary, \(n)!"
        case (.other, .warm):
            return "Thinking of you today, \(n). Wishing you a lovely \(occurrence?.event.displayTitle.lowercased() ?? "day")."
        case (.other, .playful):
            return "Hey \(n), it's your day. Go enjoy it."
        case (.other, .short):
            return "Thinking of you today, \(n)!"
        }
    }

    private func ordinal(_ n: Int) -> String {
        let style = NumberFormatter()
        style.numberStyle = .ordinal
        return style.string(from: NSNumber(value: n)) ?? "\(n)th"
    }
}
