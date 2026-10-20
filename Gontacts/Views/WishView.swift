import SwiftUI
import UIKit

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

    private var firstName: String { contact.givenName.isEmpty ? contact.displayName : contact.givenName }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
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

                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 160)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))

                Text("Drafts are written from templates and your edits. Nothing is sent until you tap send in the next app.")
                    .font(.footnote).foregroundStyle(.secondary)

                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        channel("Messages", "message.fill", enabled: true) { open("sms:\(phone)&body=\(encoded)") }
                        channel("Call", "phone.fill", enabled: !phone.isEmpty) { open("tel:\(phone)") }
                        channel("Email", "envelope.fill", enabled: contact.emails.first != nil) { open("mailto:\(contact.emails.first?.value ?? "")?body=\(encoded)") }
                        channel("Copy", "doc.on.doc", enabled: true) { UIPasteboard.general.string = text }
                    }
                }

                Spacer(minLength: 0)

                Button {
                    open("sms:\(phone)&body=\(encoded)")
                } label: {
                    Text("Send in Messages").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent).controlSize(.extraLarge)
            }
            .padding(20)
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

    private var phone: String { ContactDetailView.digits(contact.phones.first?.value ?? "") }
    private var encoded: String { text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "" }

    private func open(_ string: String) { if let url = URL(string: string) { openURL(url) } }

    private func channel(_ title: String, _ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.glass)
        .disabled(!enabled)
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
