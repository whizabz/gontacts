import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmSignOut = false
    @State private var confirmResetShowOff = false
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
                        LabeledContent("Muted contacts", value: "\(settings.mutedIDs.count)")
                    }
                } footer: {
                    if authStatus == .denied {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notifications are turned off for Gontacts in iOS Settings.")
                            Button("Open iOS Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                        }
                    }
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
                    NavigationLink("Why Gontacts?") { WhyThisAppExistsView() }
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Sign out of Gontacts?", isPresented: $confirmSignOut, titleVisibility: .visible) {
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
                Button("Sign in with Google") {
                    Task {
                        await model.store.signInWithGoogle()
                        if model.store.contactsAccessMissing { model.store.errorMessage = AuthError.contactsAccessMissing.localizedDescription }
                    }
                }
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
                    Text("Last synced is when Gontacts last downloaded your contacts from Google. Pull down on Contacts to sync again.")
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

    var body: some View {
        let muted = model.store.sorted.filter { model.settings.mutedIDs.contains($0.id) }
        List {
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
        .overlay {
            if muted.isEmpty {
                ContentUnavailableView("No Muted Contacts", systemImage: "bell", description: Text("Mute reminders from a contact's More menu."))
            }
        }
        .navigationTitle("Muted Contacts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
