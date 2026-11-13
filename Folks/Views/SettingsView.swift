import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmSignOut = false
    @State private var testNotificationSent = false
    @State private var signingIn = false
    @State private var confirmResetShowOff = false
    @AppStorage(NamePreference.enabled) private var preferNicknames = false
    @AppStorage(NamePreference.list) private var nicknameInList = true
    @AppStorage(NamePreference.detail) private var nicknameInDetail = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = model.settings
        NavigationStack {
            Form {
                meSection

                Section {
                    Toggle("Birthdays", isOn: $settings.birthdays)
                    Toggle("Anniversaries", isOn: $settings.anniversaries)
                    Toggle("Other dates", isOn: $settings.otherDates)
                }
                header: { Text("Reminders") }

                Section {
                    LabeledContent("Remind me", value: "On the day")
                    Toggle("Also 1 day before", isOn: $settings.dayBefore)
                    Toggle("Also 1 week before", isOn: $settings.weekBefore)
                    DatePicker("Time", selection: Binding(get: { settings.timeAsDate }, set: { settings.timeAsDate = $0 }), displayedComponents: .hourAndMinute)
                    NavigationLink {
                        MutedPeopleView()
                    } label: {
                        LabeledContent("Muted", value: "\(settings.mutedIDs.count + settings.mutedEvents.count)")
                    }
                } footer: {
                    if authStatus == .denied {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notifications are turned off for Folks in iOS Settings.")
                            Button("Open iOS Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                        }
                    }
                }

                if model.store.isShowingSample {
                    Section {
                        Button("Send Test Notification") { sendTestNotification() }
                    } footer: {
                        Text(testNotificationSent
                             ? "Sent. It arrives in about 5 seconds. Lock your phone or leave the app to see it as a banner, then press and hold it for the actions."
                             : "Sends a sample birthday reminder from a demo contact so you can try the notification and its actions.")
                    }
                }

                Section {
                    Toggle("Prefer nicknames", isOn: $preferNicknames.animation())
                    if preferNicknames {
                        Toggle("In the contact list", isOn: $nicknameInList)
                        Toggle("In contact details", isOn: $nicknameInDetail)
                    }
                } header: {
                    Text("Names")
                } footer: {
                    Text("Contacts with a nickname show only the nickname, without their other names. Everyone else shows their full name, including prefix, middle name and suffix.")
                }

                Section {
                    Toggle("Confetti", isOn: $settings.confetti)
                } header: {
                    Text("Celebrations")
                } footer: {
                    Text("Shows confetti when you open a contact whose birthday or anniversary is today. This follows your Reduce Motion accessibility setting.")
                }

                accountSection

                showOffSection

                Section {
                    NavigationLink("Why Folks?") { WhyThisAppExistsView() }
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        HStack {
                            Text("App Settings")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app").foregroundStyle(.secondary)
                        }
                        .contentShape(.rect)
                    }
                    .foregroundStyle(.primary)
                } footer: {
                    Text("Manage notifications, badges, contacts access and language in the iOS Settings app.")
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Sign out of Folks?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    model.store.signOut()
                    model.hasOnboarded = false
                    Task { await ReminderScheduler.reschedule(contacts: [], settings: model.settings) }
                }
            } message: { Text("Contacts stay in your Google account. Reminders on this device are removed.") }
            .alert("Reset Sample Contacts?", isPresented: $confirmResetShowOff) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    model.store.resetSampleData()
                    model.cards.resetDemoCards()
                    model.resetNavigation()
                    model.rescheduleReminders()
                }
            } message: { Text("Sample contacts and contact cards go back to how they started. Your Google contacts aren't affected.") }
        }
        .task { authStatus = await ReminderScheduler.authorizationStatus() }
        .onChange(of: settings.birthdays) { _, _ in changed() }
        .onChange(of: settings.anniversaries) { _, _ in changed() }
        .onChange(of: settings.otherDates) { _, _ in changed() }
        .onChange(of: settings.dayBefore) { _, _ in changed() }
        .onChange(of: settings.weekBefore) { _, _ in changed() }
        .onChange(of: settings.timeOfDay) { _, _ in changed() }
    }

    private func sendTestNotification() {
        guard let contact = model.store.sorted.first(where: { $0.events.contains { $0.kind == .birthday } }) ?? model.store.sorted.first else { return }
        Task {
            let sent = await ReminderScheduler.sendTest(for: contact)
            authStatus = await ReminderScheduler.authorizationStatus()
            testNotificationSent = sent
        }
    }

    private func changed() {
        Task {
            if await ReminderScheduler.authorizationStatus() == .notDetermined { await ReminderScheduler.requestAuthorization() }
            authStatus = await ReminderScheduler.authorizationStatus()
            model.rescheduleReminders()
        }
    }
}

extension SettingsView {
    /// My Card, and below it the contact cards you share from it (only once a My Card is chosen).
    @ViewBuilder
    fileprivate var meSection: some View {
        if model.store.isShowingSample || model.store.canSync {
            Section {
                if model.store.isShowingSample {
                    LabeledContent("My Card", value: model.store.myCard?.displayName ?? "None")
                } else {
                    NavigationLink {
                        MyCardPicker()
                    } label: {
                        LabeledContent("My Card", value: model.store.myCard?.displayName ?? "None")
                    }
                }
                if let card = model.store.myCard {
                    NavigationLink {
                        ContactCardsView()
                    } label: {
                        let count = model.cards.cards.count + 1
                        LabeledContent("Contact Cards", value: "\(count) \(count == 1 ? "card" : "cards")")
                    }
                    .id(card.id)
                }
            } header: { Text("Me") }
        }
    }

    @ViewBuilder
    fileprivate var accountSection: some View {
        if model.store.mode == .demo {
            Section {
                LabeledContent("Contacts", value: "Sample contacts")
                Button {
                    signingIn = true
                    Task {
                        await model.store.signInWithGoogle()
                        signingIn = false
                        if model.store.contactsAccessMissing { model.store.errorMessage = AuthError.contactsAccessMissing.localizedDescription }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(signingIn ? (model.store.isSyncing ? "Syncing your contacts…" : "Connecting…") : "Sign in with Google")
                        if signingIn { ProgressView() }
                    }
                }
                .disabled(signingIn)
            } header: {
                Text("Account")
            } footer: {
                Text("You're exploring with sample contacts. Sign in to see and edit your own Google Contacts.")
            }
        } else {
            Section {
                LabeledContent("Account", value: model.store.isDemoOverlay ? "Sample account" : (model.store.accountEmail ?? "Google"))
                if model.store.canSync {
                    LabeledContent("Last synced") {
                        if model.store.isSyncing {
                            Text("Syncing…")
                        } else if let last = model.store.lastSynced {
                            TimelineView(.periodic(from: .now, by: 30)) { _ in
                                Text(last.formatted(.relative(presentation: .named)))
                            }
                        } else {
                            Text("Never")
                        }
                    }
                    if !model.store.pending.isEmpty {
                        LabeledContent("Waiting to sync") {
                            Text("\(model.store.pending.count) \(model.store.pending.count == 1 ? "change" : "changes")")
                        }
                    }
                    Button("Sync Now") { Task { await model.store.flushPending(); await model.store.sync() } }
                        .disabled(model.store.isSyncing)
                }
                if !model.store.isDemoOverlay {
                    Button("Sign Out", role: .destructive) { confirmSignOut = true }
                }
            } header: {
                Text("Account")
            } footer: {
                if !model.store.isDemoOverlay {
                    Text("Last synced is when Folks last downloaded your contacts from Google. Pull down on Contacts to sync again.")
                }
            }
        }
    }

    @ViewBuilder
    fileprivate var showOffSection: some View {
        if model.store.mode == .demo {
            Section {
                Button("Reset Sample Contacts") { confirmResetShowOff = true }
            }
        } else if model.store.mode == .google {
            Section {
                Toggle("Show-off Mode", isOn: Binding(
                    get: { model.store.isDemoOverlay },
                    set: { on in
                        model.store.setDemoOverlay(on)
                        model.rescheduleReminders()
                    }
                ))
                if model.store.isDemoOverlay {
                    Button("Reset Sample Contacts") { confirmResetShowOff = true }
                }
            } footer: {
                Text(model.store.isDemoOverlay
                     ? "Showing sample contacts and events. Your Google contacts aren't touched, synced or used for reminders until you turn this off."
                     : "Show-off Mode shows sample contacts so you can show off the app.")
            }
        }
    }
}

struct MutedPeopleView: View {
    @Environment(AppModel.self) private var model

    /// A muted single reminder, decoded from its key ("contactID|kind|label").
    private struct MutedEvent: Identifiable {
        let key: String
        let contact: Contact
        let title: String
        var id: String { key }
    }

    private var mutedEvents: [MutedEvent] {
        model.settings.mutedEvents.compactMap { key in
            let parts = key.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3, let contact = model.store.contact(id: parts[0]), let kind = EventKind(rawValue: parts[1]) else { return nil }
            return MutedEvent(key: key, contact: contact, title: kind == .other && !parts[2].isEmpty ? parts[2] : kind.title)
        }
        .sorted { $0.contact.sortName.localizedStandardCompare($1.contact.sortName) == .orderedAscending }
    }

    var body: some View {
        let muted = model.store.sorted.filter { model.settings.mutedIDs.contains($0.id) }
        let events = mutedEvents
        List {
            if !muted.isEmpty {
                Section("All reminders") {
                    ForEach(muted) { c in
                        HStack(spacing: 12) { AvatarView(contact: c, size: 36); Text(c.displayName) }
                            .swipeActions {
                                Button("Unmute") {
                                    model.settings.mutedIDs.remove(c.id)
                                    model.rescheduleReminders()
                                }.tint(.accentColor)
                            }
                    }
                }
            }
            if !events.isEmpty {
                Section("Single reminders") {
                    ForEach(events) { e in
                        HStack(spacing: 12) {
                            AvatarView(contact: e.contact, size: 36)
                            VStack(alignment: .leading) {
                                Text(e.contact.displayName)
                                Text(e.title).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button("Unmute") {
                                model.settings.mutedEvents.remove(e.key)
                                model.rescheduleReminders()
                            }.tint(.accentColor)
                        }
                    }
                }
            }
        }
        .overlay {
            if muted.isEmpty && events.isEmpty {
                ContentUnavailableView("Nothing Muted", systemImage: "bell", description: Text("Mute reminders from a contact's More menu or a reminder notification."))
            }
        }
        .navigationTitle("Muted")
        .navigationBarTitleDisplayMode(.inline)
    }
}
