import SwiftUI
import UserNotifications

enum OnboardingStep: Hashable { case connect, reminders }

struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView { path.append(.connect) }
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .connect: ConnectView { path.append(.reminders) }
                    case .reminders: ReminderOptInView()
                    }
                }
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3).foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.15), in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 40)
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 44)).foregroundStyle(.tint)
                .frame(width: 84, height: 84)
                .glassEffect(.regular, in: .rect(cornerRadius: 26))
            Text("Your Google Contacts, done right.")
                .font(.largeTitle.bold())
            Text("A simple contacts app for iPhone and iPad that talks straight to Google.")
                .font(.title3).foregroundStyle(.secondary)
            VStack(spacing: 12) {
                FeatureRow(symbol: "pencil", tint: .indigo, title: "Edit everything", detail: "Names, numbers, labels and dates.")
                FeatureRow(symbol: "calendar", tint: .green, title: "Dates that stay correct", detail: "Birthdays without a year are kept as Google keeps them.")
                FeatureRow(symbol: "birthday.cake", tint: .pink, title: "Remember and wish", detail: "Reminders for birthdays and anniversaries.")
            }
            .padding(.top, 8)
            Spacer()
            Button(action: onContinue) {
                Text("Get started").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent).controlSize(.extraLarge)
        }
        .padding(.horizontal, 24).padding(.bottom, 12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct ConnectView: View {
    @Environment(AppModel.self) private var model
    let onConnected: () -> Void
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect your Google account").font(.largeTitle.bold())
            Text("Gontacts shows and edits the contacts you already have in Google. Nothing is copied to another server.")
                .font(.title3).foregroundStyle(.secondary)

            VStack(spacing: 0) {
                row("person.2", .blue, "Contacts", "View, add, edit and delete")
                Divider().padding(.leading, 60)
                row("envelope", .orange, "Email address", "To show which account is signed in")
                Divider().padding(.leading, 60)
                row("lock", .green, "Kept on this device", "Sign-in token lives in the Keychain")
            }
            .padding(.horizontal, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
            .padding(.top, 8)

            Spacer()

            if !GoogleAuth.isConfigured {
                Text("Google sign-in isn't set up yet. Add your OAuth client ID to Config/Secrets.xcconfig, or explore with sample contacts.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Button {
                working = true
                Task {
                    await model.store.signInWithGoogle()
                    working = false
                    if model.store.mode == .google { onConnected() }
                }
            } label: {
                Text("Continue with Google").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent).controlSize(.extraLarge)
            .disabled(working)

            Button {
                model.store.useSampleContacts()
                onConnected()
            } label: {
                Text("Use Sample Contacts").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass).controlSize(.extraLarge)
        }
        .padding(.horizontal, 24).padding(.bottom, 12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ symbol: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.15), in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

struct ReminderOptInView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        VStack(alignment: .leading, spacing: 16) {
            Text("Never miss a birthday").font(.largeTitle.bold())
            Text("Gontacts reads the birthdays and anniversaries in your contacts and reminds you on the day.")
                .font(.title3).foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "birthday.cake")
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.tint, in: .rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    HStack { Text("GONTACTS"); Spacer(); Text("now") }.font(.footnote).foregroundStyle(.secondary)
                    Text("Hana Ito's birthday").font(.subheadline.weight(.semibold))
                    Text("Turns 34 today. Send wishes?").font(.subheadline)
                }
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .padding(.top, 8)

            VStack(spacing: 0) {
                LabeledContent("Remind me", value: "On the day").frame(minHeight: 48)
                Divider()
                DatePicker("At", selection: Binding(get: { settings.timeAsDate }, set: { settings.timeAsDate = $0 }), displayedComponents: .hourAndMinute).frame(minHeight: 48)
                Divider()
                Toggle("Also remind me 1 day before", isOn: $settings.dayBefore).frame(minHeight: 48)
            }
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))

            Spacer()

            Button {
                Task {
                    await ReminderScheduler.requestAuthorization()
                    finish()
                }
            } label: {
                Text("Turn on reminders").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent).controlSize(.extraLarge)
            Text("iOS will ask to allow notifications. You can change this in Settings.")
                .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24).padding(.bottom, 12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Skip") { finish() } }
        }
    }

    private func finish() {
        model.hasOnboarded = true
        model.rescheduleReminders()
    }
}
