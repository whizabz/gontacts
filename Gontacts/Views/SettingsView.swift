import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmSignOut = false

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
                    NavigationLink("Why This App Exists") { WhyThisAppExistsView() }
                }

                Section("Account") {
                    LabeledContent("Account", value: model.store.accountEmail ?? "Sample contacts")
                    if model.store.mode == .google {
                        LabeledContent("Synced") {
                            if let last = model.store.lastSynced { Text(last, style: .relative) } else { Text("Never") }
                        }
                        Button("Sync Now") { Task { await model.store.sync() } }
                            .disabled(model.store.isSyncing)
                    }
                    Button("Sign Out", role: .destructive) { confirmSignOut = true }
                }
            }
            .navigationTitle("Settings")
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

struct WhyThisAppExistsView: View {
    private var body1: Text {
        Text("Gontacts is mainly for people who keep Google Contacts as the one place for all their contacts, and who use it to store important dates, like birthdays and anniversaries, to use later. Apple Contacts has trouble saving dates to Google Contacts, and that is the reason this app exists. Apple stores a birthday with no year as ")
        + code("1604-11-26") + Text(" with an ") + code("X-APPLE-OMIT-YEAR=1604")
        + Text(" flag. Google stores the same date as ") + code("--1126")
        + Text(", which is vCard 4.0 shorthand inside a vCard 3.0 file. iOS can't parse that over CardDAV, so year-less birthdays vanish on the iPhone. Gontacts works with Google's own format, so those dates stay intact.")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 40)).foregroundStyle(.tint)
                    .frame(width: 84, height: 84)
                    .background(Color.accentColor.opacity(0.15), in: .rect(cornerRadius: 26))
                Text("Why This App Exists").font(.title.bold()).multilineTextAlignment(.center)
                body1
                    .font(.body).lineSpacing(5)
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 28))
                    .padding(.top, 6)
            }
            .padding(.horizontal, 16).padding(.top, 12)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func code(_ s: String) -> Text {
        Text(s).font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
    }
}
