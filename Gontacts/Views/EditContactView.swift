import SwiftUI

struct EditContactView: View {
    let original: Contact
    var onSaved: ((Contact) -> Void)?

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Contact
    @State private var expandedEvent: UUID?
    @State private var confirmDiscard = false
    @State private var saving = false
    @State private var errorMessage: String?

    init(contact: Contact, onSaved: ((Contact) -> Void)? = nil) {
        original = contact
        self.onSaved = onSaved
        _draft = State(initialValue: contact)
    }

    private var hasChanges: Bool { draft != original }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("First name", text: $draft.givenName).textContentType(.givenName)
                    TextField("Last name", text: $draft.familyName).textContentType(.familyName)
                    TextField("Company", text: $draft.organization)
                    TextField("Job title", text: $draft.jobTitle)
                }

                valueSection("Phone", values: $draft.phones, labels: ["mobile", "home", "work", "other"], keyboard: .phonePad)
                valueSection("Email", values: $draft.emails, labels: ["home", "work", "other"], keyboard: .emailAddress)

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

    private func valueSection(_ title: String, values: Binding<[LabeledValue]>, labels: [String], keyboard: UIKeyboardType) -> some View {
        Section {
            ForEach(values) { $item in
                HStack {
                    Menu {
                        Picker("Label", selection: $item.label) {
                            ForEach(labels, id: \.self) { Text($0.capitalized).tag($0) }
                        }
                    } label: {
                        Text(item.label.capitalized).frame(width: 74, alignment: .leading)
                    }
                    TextField(title, text: $item.value).keyboardType(keyboard).textInputAutocapitalization(.never)
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
