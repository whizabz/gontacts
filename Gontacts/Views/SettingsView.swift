import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmSignOut = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = model.settings
        NavigationStack {
            Form {
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
                        LabeledContent("Muted people", value: "\(settings.mutedIDs.count)")
                    }
                } footer: {
                    if authStatus == .denied {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notifications are turned off for Gontacts in iOS Settings.")
                            Button("Open iOS Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                        }
                    } else {
                        Text("Reminders are scheduled on this device from the dates in your contacts.")
                    }
                }

                Section {
                    Toggle("Confetti", isOn: $settings.confetti)
                } header: {
                    Text("Celebrations")
                } footer: {
                    Text("Shows confetti when you open a contact whose birthday or anniversary is today. It's always skipped when Reduce Motion is on in iOS Settings.")
                }

                Section {
                    NavigationLink("Why This App Exists") { WhyThisAppExistsView() }
                }

                accountSection
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
                LabeledContent("Account", value: model.store.accountEmail ?? "Google")
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
                    NavigationLink {
                        MyCardPicker()
                    } label: {
                        LabeledContent("My Card", value: model.store.myCard?.displayName ?? "None")
                    }
                    Button("Sync Now") { Task { await model.store.flushPending(); await model.store.sync() } }
                        .disabled(model.store.isSyncing)
                }
                Toggle("Demo Mode", isOn: Binding(
                    get: { model.store.isDemoOverlay },
                    set: { on in
                        model.store.setDemoOverlay(on)
                        model.rescheduleReminders()
                    }
                ))
                Button("Sign Out", role: .destructive) { confirmSignOut = true }
            } header: {
                Text("Account")
            } footer: {
                Text(model.store.isDemoOverlay
                     ? "Showing sample contacts and events. Your Google contacts aren't touched, synced or used for reminders until you turn this off."
                     : "Last synced is when Gontacts last downloaded your contacts from Google. Pull down on Contacts to sync again. Demo Mode shows sample contacts so you can show off the app.")
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
                ContentUnavailableView("No Muted People", systemImage: "bell", description: Text("Mute reminders from a contact's More menu."))
            }
        }
        .navigationTitle("Muted People")
        .navigationBarTitleDisplayMode(.inline)
    }
}
