import SwiftUI

struct ContactDetailView: View {
    let contactID: String

    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var wishing = false
    @State private var confirmDelete = false
    /// Bumped on every appearance so the confetti replays each time the contact is opened.
    @State private var confettiRun = 0

    var body: some View {
        if let contact = model.store.contact(id: contactID) {
            content(contact)
        } else {
            ContentUnavailableView("Contact Not Found", systemImage: "person.crop.circle.badge.questionmark")
        }
    }

    private func content(_ contact: Contact) -> some View {
        let today = EventTimeline.events(on: .now, for: contact)
        let muted = model.settings.mutedIDs.contains(contact.id)

        return List {
            Section {
                VStack(spacing: 6) {
                    AvatarView(contact: contact, size: 96)
                    Text(contact.displayName).font(.title.bold()).multilineTextAlignment(.center).padding(.top, 6)
                    if !contact.nickname.isEmpty { Text("“\(contact.nickname)”").foregroundStyle(.secondary) }
                    if !contact.subtitle.isEmpty { Text(contact.subtitle).foregroundStyle(.secondary) }
                    if model.store.canSync {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark").imageScale(.small)
                            Text("Synced with Google")
                        }
                        .font(.caption)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                    }
                    actionButtons(contact).padding(.top, 12)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            if let event = today.first {
                Section {
                    Button { wishing = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: event.event.kind.symbol).font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bannerTitle(contact, event)).font(.headline).multilineTextAlignment(.leading)
                                Text(bannerDetail(event)).font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Send wishes").font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.glassProminent).controlSize(.large)
                    .listRowBackground(Color.clear).listRowInsets(.init())
                }
            }

            if !contact.phones.isEmpty || !contact.emails.isEmpty {
                Section {
                    ForEach(contact.phones) { p in
                        LabeledContent(p.label) { Button(p.value) { call(p.value) }.buttonStyle(.plain).foregroundStyle(.tint) }
                    }
                    ForEach(contact.emails) { e in
                        LabeledContent(e.label) { Button(e.value) { mail(e.value) }.buttonStyle(.plain).foregroundStyle(.tint) }
                    }
                }
            }

            if !contact.addresses.filter({ !$0.isEmpty }).isEmpty {
                Section("Address") {
                    ForEach(contact.addresses.filter { !$0.isEmpty }) { a in
                        Button { openMap(a) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a.label).font(.footnote).foregroundStyle(.secondary)
                                Text(a.formatted).foregroundStyle(.tint).multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !contact.urls.isEmpty {
                Section("Website") {
                    ForEach(contact.urls) { u in
                        LabeledContent(u.label) { Button(u.value) { openWebsite(u.value) }.buttonStyle(.plain).foregroundStyle(.tint) }
                    }
                }
            }

            if !contact.relations.isEmpty {
                Section("Related people") {
                    ForEach(contact.relations) { r in LabeledContent(r.label, value: r.value) }
                }
            }

            if !contact.ims.isEmpty {
                Section("Messaging and social") {
                    ForEach(contact.ims) { i in LabeledContent(i.label.displayLabel, value: i.value) }
                }
            }

            if !contact.customFields.isEmpty {
                Section("Custom fields") {
                    ForEach(contact.customFields) { f in LabeledContent(f.label, value: f.value) }
                }
            }

            if !contact.events.isEmpty {
                Section("Dates") {
                    ForEach(contact.events) { e in
                        LabeledContent {
                            Text(e.date.formatted())
                        } label: {
                            Label { Text(e.displayTitle) } icon: { Image(systemName: e.kind.symbol).foregroundStyle(e.kind.tint) }
                        }
                    }
                }
            }

            if !contact.notes.isEmpty {
                Section("Notes") { Text(contact.notes) }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if !today.isEmpty && !reduceMotion && model.settings.confetti {
                ConfettiView().id(confettiRun).frame(maxHeight: .infinity).ignoresSafeArea()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
                Menu {
                    Toggle(isOn: Binding(get: { muted }, set: { setMuted($0, contact) })) {
                        Label("Mute Reminders", systemImage: "bell.slash")
                    }
                    Button("Delete Contact", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: { Label("More", systemImage: "ellipsis") }
            }
        }
        .sheet(isPresented: $editing) { EditContactView(contact: contact) }
        .sheet(isPresented: $wishing) { WishView(contact: contact, occurrence: today.first) }
        .confirmationDialog("Delete \(contact.displayName)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Contact", role: .destructive) {
                Task {
                    do {
                        try await model.store.delete(contact)
                        if model.contactsSelection == contact.id { model.contactsSelection = nil }
                        dismiss()
                    } catch { model.store.errorMessage = error.localizedDescription }
                }
            }
        } message: { Text("This also deletes it from Google Contacts.") }
        .onAppear {
            confettiRun += 1
            if model.wishRequestID == contact.id, !today.isEmpty {
                model.wishRequestID = nil
                wishing = true
            }
        }
    }

    private func actionButtons(_ contact: Contact) -> some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                actionButton("Message", "message.fill", enabled: contact.phones.first != nil) { text(contact.phones.first?.value ?? "") }
                actionButton("Call", "phone.fill", enabled: contact.phones.first != nil) { call(contact.phones.first?.value ?? "") }
                actionButton("Email", "envelope.fill", enabled: contact.emails.first != nil) { mail(contact.emails.first?.value ?? "") }
            }
        }
        .frame(maxWidth: 420)
    }

    private func actionButton(_ title: String, _ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.glass)
        .disabled(!enabled)
    }

    private func bannerTitle(_ c: Contact, _ o: EventOccurrence) -> String {
        let first = c.givenName.isEmpty ? c.displayName : c.givenName
        switch o.event.kind {
        case .birthday: return "It's \(first)'s birthday"
        case .anniversary: return "It's \(first)'s anniversary"
        case .other: return "\(o.event.displayTitle) today"
        }
    }

    private func bannerDetail(_ o: EventOccurrence) -> String {
        switch (o.event.kind, o.years) {
        case (.birthday, let y?): "Turns \(y) today"
        case (_, let y?): "\(y) \(y == 1 ? "year" : "years") today"
        default: "Today"
        }
    }

    private func setMuted(_ on: Bool, _ c: Contact) {
        if on { model.settings.mutedIDs.insert(c.id) } else { model.settings.mutedIDs.remove(c.id) }
        model.rescheduleReminders()
    }

    private func call(_ number: String) { if let url = URL(string: "tel:" + Self.digits(number)) { openURL(url) } }
    private func text(_ number: String) { if let url = URL(string: "sms:" + Self.digits(number)) { openURL(url) } }
    private func mail(_ address: String) { if let url = URL(string: "mailto:" + address) { openURL(url) } }

    private func openMap(_ a: PostalAddress) {
        let query = a.formatted.replacingOccurrences(of: "\n", with: ", ").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?q=\(query)") { openURL(url) }
    }

    private func openWebsite(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespaces)
        let withScheme = text.contains("://") ? text : "https://" + text
        if let url = URL(string: withScheme) { openURL(url) }
    }

    static func digits(_ s: String) -> String { s.filter { $0.isNumber || $0 == "+" } }
}
