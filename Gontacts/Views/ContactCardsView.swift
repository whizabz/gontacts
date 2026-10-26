import SwiftUI

/// A rounded square holding a card's symbol, in the card's colour.
struct CardTile: View {
    let symbol: String
    let colorIndex: Int
    var size: CGFloat = 40

    var body: some View {
        let color = CardColor.at(colorIndex)
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .regular))
            .foregroundStyle(color.foreground)
            .frame(width: size, height: size)
            .background(color.background, in: .rect(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// The small pencil on a tile that tells you it can be tapped to change the icon.
struct PencilBadge: View {
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: "pencil")
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.accentColor, in: .circle)
            .overlay(Circle().stroke(Color(.secondarySystemGroupedBackground), lineWidth: 2.5))
    }
}

/// Contact Cards: the named selections of your details that you can share in one tap. Opened from Settings and
/// from the card button on My Card.
struct ContactCardsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// True when shown in its own sheet (from My Card), which needs a close button.
    var inSheet = false

    @State private var creating = false
    @State private var pendingDelete: ContactCard?

    var body: some View {
        let contact = model.store.myCard
        List {
            Section {
                row(name: "Full contact", summary: "Everything · \(contact?.allShareFields.count ?? 0) details",
                    symbol: "person.text.rectangle", color: 0, isDefault: true)
                ForEach(model.cards.cards) { card in
                    NavigationLink {
                        ContactCardDetailView(cardID: card.id)
                    } label: {
                        row(name: card.name, summary: contact?.cardSummary(card.fields) ?? "", symbol: card.symbol, color: card.colorIndex, isDefault: false)
                    }
                    .swipeActions(allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) { pendingDelete = card }
                    }
                }
            } header: {
                Text("Each contact card shares only the details you choose. Tap one to share it or edit it.")
                    .textCase(nil).font(.subheadline).foregroundStyle(.secondary).padding(.bottom, 4)
            } footer: {
                Text("Contact cards are saved on this phone. Share one from your card, or choose any when you tap Share.")
            }
        }
        .navigationTitle("Contact Cards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if inSheet {
                ToolbarItem(placement: .cancellationAction) { Button(role: .close) { dismiss() } }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { creating = true } label: { Label("New Contact Card", systemImage: "plus") }
                    .disabled(contact == nil)
            }
        }
        .sheet(isPresented: $creating) {
            if let contact { ContactCardEditView(contact: contact, card: nil, defaultName: model.cards.nextDefaultName()) }
        }
        .confirmationDialog("Delete this contact card?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { card in
            Button("Delete \(card.name)", role: .destructive) { model.cards.delete(card.id) }
        } message: { _ in Text("Your contact isn't changed.") }
    }

    private func row(name: String, summary: String, symbol: String, color: Int, isDefault: Bool) -> some View {
        HStack(spacing: 14) {
            CardTile(symbol: symbol, colorIndex: color, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(name).font(.headline)
                    if isDefault {
                        Text("Default").font(.caption.weight(.semibold)).foregroundStyle(.tint)
                            .padding(.horizontal, 8).padding(.vertical, 2).background(Color.accentColor.opacity(0.12), in: .capsule)
                    }
                }
                Text(summary).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }
}

/// Make or change a contact card: its name, its icon, and which of your details it includes.
struct ContactCardEditView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let contact: Contact
    let card: ContactCard?

    @State private var name: String
    @State private var symbol: String
    @State private var colorIndex: Int
    @State private var chosen: Set<ShareField>
    @State private var pickingIcon = false
    @State private var confirmDelete = false

    /// `defaultName` is the suggested name for a new card.
    init(contact: Contact, card: ContactCard?, defaultName: String = "") {
        self.contact = contact
        self.card = card
        _name = State(initialValue: card?.name ?? defaultName)
        _symbol = State(initialValue: card?.symbol ?? "briefcase")
        _colorIndex = State(initialValue: card?.colorIndex ?? 1)
        _chosen = State(initialValue: card.map { contact.shareFields(for: $0.fields) } ?? contact.shareFields(for: ["name"]))
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !chosen.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        Button { pickingIcon = true } label: {
                            CardTile(symbol: symbol, colorIndex: colorIndex, size: 48)
                                .overlay(alignment: .bottomTrailing) { PencilBadge().offset(x: 5, y: 5) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Change icon")
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Name").font(.caption).foregroundStyle(.secondary)
                            TextField("Card name", text: $name).font(.title3.weight(.semibold))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
                    Text("Tap the icon to change it.").font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.top, -8)

                    Text("Include in this contact card").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                        .padding(.leading, 20).padding(.bottom, -8)
                    ShareFieldList(contact: contact, chosen: $chosen)
                    Text("A contact card shares only the selected details. If one of your details changes, select it again here.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 20)

                    if card != nil {
                        Button("Delete Contact Card", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity).padding(.top, 8)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(card == nil ? "New Contact Card" : "Edit Contact Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(role: .confirm) { save() }.disabled(!canSave) }
            }
            .sheet(isPresented: $pickingIcon) { CardIconPicker(symbol: $symbol, colorIndex: $colorIndex) }
            .confirmationDialog("Delete this contact card?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Contact Card", role: .destructive) {
                    if let card { model.cards.delete(card.id) }
                    dismiss()
                }
            } message: { Text("Your contact isn't changed.") }
        }
    }

    private func save() {
        var saved = card ?? ContactCard(name: "", symbol: symbol, colorIndex: colorIndex, fields: [])
        saved.name = name.trimmingCharacters(in: .whitespaces)
        saved.symbol = symbol
        saved.colorIndex = colorIndex
        saved.fields = contact.shareKeys(for: chosen)
        model.cards.save(saved)
        dismiss()
    }
}

/// Choose a card's colour and symbol. Changes only apply when you tap the checkmark.
struct CardIconPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var symbol: String
    @Binding var colorIndex: Int

    @State private var draftSymbol: String
    @State private var draftColor: Int
    @State private var tab = Tab.glyph
    @State private var query = ""

    private enum Tab: String, CaseIterable, Identifiable {
        case color = "Color", glyph = "Glyph"
        var id: String { rawValue }
    }

    private static let groups: [(title: String, symbols: [String])] = [
        ("People", ["person", "person.2", "person.text.rectangle", "heart", "star", "house"]),
        ("Work", ["briefcase", "building.2", "graduationcap", "bag", "book", "bolt"]),
        ("Communication", ["bubble.left", "phone", "envelope", "globe", "at", "camera"]),
        ("Life", ["gift", "birthday.cake", "music.note", "airplane", "car", "mappin"]),
    ]

    init(symbol: Binding<String>, colorIndex: Binding<Int>) {
        _symbol = symbol
        _colorIndex = colorIndex
        _draftSymbol = State(initialValue: symbol.wrappedValue)
        _draftColor = State(initialValue: colorIndex.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    CardTile(symbol: draftSymbol, colorIndex: draftColor, size: 76).padding(.top, 6)
                    Picker("Edit", selection: $tab) {
                        ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if tab == .color {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(CardColor.all.indices, id: \.self) { i in
                                Button { draftColor = i } label: {
                                    CardTile(symbol: draftSymbol, colorIndex: i, size: 64)
                                        .overlay { if draftColor == i { RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(Color.accentColor, lineWidth: 2.5) } }
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(draftColor == i ? .isSelected : [])
                            }
                        }
                    } else {
                        ForEach(filteredGroups, id: \.title) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                                    ForEach(group.symbols, id: \.self) { name in
                                        Button { draftSymbol = name } label: {
                                            Image(systemName: name).font(.title3)
                                                .foregroundStyle(draftSymbol == name ? Color.accentColor : .primary)
                                                .frame(maxWidth: .infinity, minHeight: 50)
                                                .background(draftSymbol == name ? Color.accentColor.opacity(0.14) : Color(.secondarySystemGroupedBackground),
                                                            in: .rect(cornerRadius: 14, style: .continuous))
                                                .overlay { if draftSymbol == name { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.accentColor, lineWidth: 2) } }
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(name.replacingOccurrences(of: ".", with: " "))
                                        .accessibilityAddTraits(draftSymbol == name ? .isSelected : [])
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .searchable(text: $query, prompt: "Search")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .navigationTitle("Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        symbol = draftSymbol
                        colorIndex = draftColor
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var filteredGroups: [(title: String, symbols: [String])] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return Self.groups }
        return Self.groups.compactMap { group in
            let matches = group.symbols.filter { $0.contains(q) || group.title.lowercased().contains(q) }
            return matches.isEmpty ? nil : (group.title, matches)
        }
    }
}

/// One contact card: share it, show it as a QR code, or tap Edit to change it.
struct ContactCardDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let cardID: UUID

    @State private var editing = false
    @State private var showQR = false

    var body: some View {
        Group {
            if let card = model.cards.card(cardID), let contact = model.store.myCard {
                let fields = contact.shareFields(for: card.fields)
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 10) {
                            CardTile(symbol: card.symbol, colorIndex: card.colorIndex, size: 72)
                            Text(card.name).font(.title2.bold())
                            Text(contact.cardSummary(card.fields)).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .padding(.top, 12)
                        VStack(spacing: 12) {
                            Button { share(contact, fields) } label: {
                                Label("Share", systemImage: "square.and.arrow.up").font(.headline).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent)
                            Button { showQR = true } label: {
                                Label("Show QR Code", systemImage: "qrcode").font(.headline).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glass)
                        }
                        .controlSize(.extraLarge)
                        .disabled(fields.isEmpty)
                        sharedDetails(contact, fields)
                    }
                    .padding(20)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle(card.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) { Button("Edit") { editing = true } }
                }
                .navigationDestination(isPresented: $showQR) { ContactQRView(contact: contact.keeping(fields)) }
                .sheet(isPresented: $editing) { ContactCardEditView(contact: contact, card: card) }
            } else {
                // Deleted from the edit screen: nothing left to show.
                Color.clear.onAppear { dismiss() }
            }
        }
    }

    /// The details this card shares: the rows ticked in Edit, grouped as they are there.
    @ViewBuilder
    private func sharedDetails(_ contact: Contact, _ fields: Set<ShareField>) -> some View {
        let groups = contact.shareGroups.map { $0.filter { fields.contains($0.field) } }.filter { !$0.isEmpty }
        if groups.isEmpty {
            Text("Nothing is shared. Tap Edit to choose details.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("SHARED DETAILS").font(.footnote).foregroundStyle(.secondary).padding(.leading, 16)
                ForEach(Array(groups.enumerated()), id: \.offset) { _, rows in
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            if index > 0 { Divider().padding(.leading, 16) }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.label).font(.subheadline).foregroundStyle(.secondary)
                                Text(row.value).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
                }
            }
        }
    }

    private func share(_ contact: Contact, _ fields: Set<ShareField>) {
        guard let url = try? contact.keeping(fields).writeVCardFile() else { return }
        model.cards.lastUsedID = cardID
        ShareSheet.present(url)
    }
}
