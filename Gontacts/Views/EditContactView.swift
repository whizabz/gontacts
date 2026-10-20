import SwiftUI

struct EditContactView: View {
    let original: Contact
    var onSaved: ((Contact) -> Void)?

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Contact
    @State private var shown: Set<NameField>
    @State private var expandedEvent: UUID?
    @State private var confirmDiscard = false
    @State private var saving = false
    @State private var errorMessage: String?

    init(contact: Contact, onSaved: ((Contact) -> Void)? = nil) {
        original = contact
        self.onSaved = onSaved
        _draft = State(initialValue: contact)
        var initial = Set<NameField>()
        if !contact.namePrefix.isEmpty { initial.insert(.prefix) }
        if !contact.middleName.isEmpty { initial.insert(.middleName) }
        if !contact.nameSuffix.isEmpty { initial.insert(.suffix) }
        if !contact.nickname.isEmpty { initial.insert(.nickname) }
        _shown = State(initialValue: initial)
    }

    /// Optional name fields, revealed from the "Add Field" menu (or when the contact already has a value).
    enum NameField: Hashable { case prefix, middleName, suffix, nickname }

    private var hasChanges: Bool { draft != original }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if shown.contains(.prefix) { TextField("Name prefix", text: $draft.namePrefix) }
                    TextField("First name", text: $draft.givenName).textContentType(.givenName)
                    if shown.contains(.middleName) { TextField("Middle name", text: $draft.middleName) }
                    TextField("Last name", text: $draft.familyName).textContentType(.familyName)
                    if shown.contains(.suffix) { TextField("Name suffix", text: $draft.nameSuffix) }
                    if shown.contains(.nickname) { TextField("Nickname", text: $draft.nickname) }
                    TextField("Company", text: $draft.organization)
                    TextField("Job title", text: $draft.jobTitle)
                }

                valueSection("Phone", values: $draft.phones, labels: ["mobile", "home", "work", "other"], keyboard: .phonePad)
                valueSection("Email", values: $draft.emails, labels: ["home", "work", "other"], keyboard: .emailAddress)

                if !draft.addresses.isEmpty {
                    Section("Address") {
                        ForEach($draft.addresses) { $address in AddressEditor(address: $address) }
                            .onDelete { draft.addresses.remove(atOffsets: $0) }
                    }
                }
                if !draft.urls.isEmpty {
                    valueSection("Website", values: $draft.urls, labels: ["homepage", "blog", "work", "profile", "other"], keyboard: .URL)
                }
                if !draft.relations.isEmpty {
                    valueSection("Related person", values: $draft.relations, labels: ["spouse", "partner", "child", "parent", "sibling", "friend", "manager", "assistant", "other"], keyboard: .default, capitalize: true)
                }

                Section("Dates") {
                    ForEach($draft.events) { $event in
                        EventEditorRow(event: $event, expanded: expandedEvent == event.id) {
                            withAnimation { expandedEvent = expandedEvent == event.id ? nil : event.id }
                        }
                    }
                    .onDelete { draft.events.remove(atOffsets: $0) }

                    Menu {
                        Button("Birthday", systemImage: EventKind.birthday.symbol) { add(.birthday) }
                        Button("Anniversary", systemImage: EventKind.anniversary.symbol) { add(.anniversary) }
                        Button("Other", systemImage: EventKind.other.symbol) { add(.other) }
                    } label: {
                        Label("Add Date", systemImage: "plus.circle.fill")
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $draft.notes, axis: .vertical).lineLimit(3...8)
                }

                Section {
                    Menu {
                        if !shown.contains(.prefix) { Button("Name prefix") { withAnimation { _ = shown.insert(.prefix) } } }
                        if !shown.contains(.middleName) { Button("Middle name") { withAnimation { _ = shown.insert(.middleName) } } }
                        if !shown.contains(.suffix) { Button("Name suffix") { withAnimation { _ = shown.insert(.suffix) } } }
                        if !shown.contains(.nickname) { Button("Nickname") { withAnimation { _ = shown.insert(.nickname) } } }
                        Divider()
                        Button("Address", systemImage: "mappin.and.ellipse") { withAnimation { draft.addresses.append(PostalAddress()) } }
                        Button("Website", systemImage: "link") { withAnimation { draft.urls.append(LabeledValue(label: "homepage", value: "")) } }
                        Button("Related person", systemImage: "person.2") { withAnimation { draft.relations.append(LabeledValue(label: "friend", value: "")) } }
                    } label: {
                        Label("Add Field", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle(original.isNew ? "New Contact" : "Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { hasChanges ? (confirmDiscard = true) : dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(draft.isEmpty || !hasChanges || saving)
                }
            }
            .confirmationDialog("Discard changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes to \(draft.displayName). If you cancel, they will be lost.")
            }
            .alert("Couldn't Save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
        .interactiveDismissDisabled(hasChanges)
    }

    private func add(_ kind: EventKind) {
        let today = Calendar.current.dateComponents([.month, .day], from: .now)
        let event = ContactEvent(kind: kind, date: EventDate(month: today.month ?? 1, day: today.day ?? 1))
        draft.events.append(event)
        withAnimation { expandedEvent = event.id }
    }

    private func save() {
        saving = true
        Task {
            do {
                let saved = try await model.store.save(draft)
                onSaved?(saved)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                saving = false
            }
        }
    }

    private func valueSection(_ title: String, values: Binding<[LabeledValue]>, labels: [String], keyboard: UIKeyboardType, capitalize: Bool = false) -> some View {
        Section {
            ForEach(values) { $item in
                HStack {
                    Menu {
                        Picker("Label", selection: $item.label) {
                            ForEach(labels, id: \.self) { Text($0.capitalized).tag($0) }
                        }
                    } label: {
                        Text(item.label.capitalized).frame(width: 84, alignment: .leading)
                    }
                    TextField(title, text: $item.value).keyboardType(keyboard).textInputAutocapitalization(capitalize ? .words : .never)
                }
            }
            .onDelete { values.wrappedValue.remove(atOffsets: $0) }
            Button {
                values.wrappedValue.append(LabeledValue(label: labels[0], value: ""))
            } label: {
                Label("Add \(title.lowercased())", systemImage: "plus.circle.fill")
            }
        }
    }
}

struct EventEditorRow: View {
    @Binding var event: ContactEvent
    let expanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: toggle) {
                HStack {
                    Label { Text(event.displayTitle).foregroundStyle(.primary) } icon: { Image(systemName: event.kind.symbol).foregroundStyle(event.kind.tint) }
                    Spacer()
                    Text(event.date.formatted())
                        .foregroundStyle(expanded ? Color.accentColor : .secondary)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                if event.kind == .other {
                    TextField("Label (e.g. Graduation)", text: $event.label)
                }
                DateWheels(date: $event.date)
                Toggle("Include year", isOn: Binding(
                    get: { event.date.hasYear },
                    set: { on in
                        event.date.year = on ? Calendar.current.component(.year, from: .now) - 30 : nil
                        event.date.clamp()
                    }
                ))
                if !event.date.hasYear {
                    Label("Saved to Google as \(event.date.formatted()) with no year. No placeholder year is ever written.", systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct DateWheels: View {
    @Binding var date: EventDate

    private static let years = Array(1900...Calendar.current.component(.year, from: .now))

    var body: some View {
        HStack(spacing: 0) {
            Picker("Month", selection: Binding(get: { date.month }, set: { date.month = $0; date.clamp() })) {
                ForEach(1...12, id: \.self) { Text(Calendar.current.monthSymbols[$0 - 1]).tag($0) }
            }
            .pickerStyle(.wheel)
            Picker("Day", selection: $date.day) {
                ForEach(1...date.daysInMonth(), id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: 80)
            if date.hasYear {
                Picker("Year", selection: Binding(get: { date.year ?? 2000 }, set: { date.year = $0; date.clamp() })) {
                    ForEach(Self.years, id: \.self) { Text(String($0)).tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: 100)
            }
        }
        .labelsHidden()
        .frame(height: 130)
    }
}

struct AddressEditor: View {
    @Binding var address: PostalAddress
    private static let labels = ["home", "work", "other"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                Picker("Label", selection: $address.label) {
                    ForEach(Self.labels, id: \.self) { Text($0.capitalized).tag($0) }
                }
            } label: {
                Text(address.label.capitalized)
            }
            TextField("Street", text: $address.street).textContentType(.streetAddressLine1)
            TextField("City", text: $address.city).textContentType(.addressCity)
            HStack {
                TextField("State / region", text: $address.region).textContentType(.addressState)
                TextField("Postal code", text: $address.postalCode).textContentType(.postalCode)
            }
            TextField("Country", text: $address.country).textContentType(.countryName)
        }
    }
}
