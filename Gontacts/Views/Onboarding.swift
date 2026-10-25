import SwiftUI
import UIKit
import UserNotifications

enum OnboardingStep: Hashable { case why, connect, access, myCard, reminders }

struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView { path.append(.why) }
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .why:
                        WhyThisAppExistsView(onContinue: { path.append(.connect) })
                    case .connect:
                        ConnectView(onConnected: { path.append(model.store.mode == .google ? .myCard : .reminders) },
                                    onAccessMissing: { path.append(.access) })
                    case .access:
                        ContactsAccessNeededView(onConnected: { path.append(.myCard) },
                                                 onSampleContacts: { path.append(.reminders) })
                    case .myCard:
                        MyCardSetupView { path.append(.reminders) }
                    case .reminders:
                        ReminderOptInView()
                    }
                }
        }
    }
}

/// An icon tile with a title and a line of text. Plain on purpose: these explain, they don't do anything.
private struct InfoRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    var tile: CGFloat = 40

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: tile * 0.5, weight: .medium)).foregroundStyle(tint)
                .frame(width: tile, height: tile)
                .background(tint.opacity(0.15), in: .rect(cornerRadius: tile * 0.3))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The app's own icon. Uses the exported artwork when the asset catalog has it, otherwise the icon file in the bundle.
private struct AppIconImage: View {
    var size: CGFloat = 84
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // "AppIconArt" has a light and a dark rendering of the icon; the asset catalog picks the one that matches.
        Image("AppIconArt").resizable().interpolation(.high).scaledToFit()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.2237, style: .continuous))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.18), radius: 10, y: 6)
        .accessibilityHidden(true)
    }
}

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 24)
            AppIconImage()
            Text("Google Contacts, done right.")
                .font(.largeTitle.bold())
            Text("A simple contacts app for iPhone and iPad that talks straight to Google.")
                .font(.title3).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 22) {
                InfoRow(symbol: "person.2", tint: .indigo, title: "Manage all your contacts",
                        detail: "View, search and edit everything you have in Google Contacts.")
                InfoRow(symbol: "party.popper", tint: .pink, title: "Never miss a celebration",
                        detail: "Get reminded on the day, then send your wishes.")
                InfoRow(symbol: "person.crop.rectangle", tint: .green, title: "Share the right you.",
                        detail: "Create contact cards with only the details you choose, and share them with a tap or a QR code.")
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
    let onAccessMissing: () -> Void
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect your Google account").font(.largeTitle.bold())
            Text("To show and manage your contacts, Gontacts needs access to your Google account.")
                .font(.title3).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 26) {
                InfoRow(symbol: "person.crop.circle", tint: .blue, title: "Contacts permission",
                        detail: "On the next screen, Google will ask you to allow Gontacts to see, edit, download and delete your contacts. Please allow it so the app can work.",
                        tile: 36)
                InfoRow(symbol: "checkmark.shield", tint: .green, title: "Privacy first",
                        detail: "Your contacts stay between you and Google. Gontacts has no servers, and your sign-in is stored securely on this phone.",
                        tile: 36)
            }
            .padding(.top, 16)

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
                    else if model.store.contactsAccessMissing { onAccessMissing() }
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
}

/// Shown when Google signed the person in but the contacts permission was unticked on its screen.
struct ContactsAccessNeededView: View {
    @Environment(AppModel.self) private var model
    let onConnected: () -> Void
    let onSampleContacts: () -> Void
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 28, weight: .medium)).foregroundStyle(.orange)
                .frame(width: 56, height: 56)
                .background(Color.orange.opacity(0.15), in: .rect(cornerRadius: 16))
                .padding(.top, 8)
            Text("Contacts access is needed").font(.largeTitle.bold())
            Text("You're signed in to Google, but Gontacts wasn't given permission to see and edit your contacts. The app can't work without it.")
                .font(.title3).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Text("On Google's screen, keep this ticked").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.square.fill").font(.title2).foregroundStyle(.tint)
                    Text("See, edit, download and permanently delete your contacts").font(.body)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
            .padding(.top, 8)
            .accessibilityElement(children: .combine)

            Spacer()

            Button {
                working = true
                Task {
                    await model.store.signInWithGoogle()
                    working = false
                    if model.store.mode == .google { onConnected() }
                }
            } label: {
                Text("Try again").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent).controlSize(.extraLarge)
            .disabled(working)

            Button {
                model.store.useSampleContacts()
                onSampleContacts()
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
}

struct ReminderOptInView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        VStack(alignment: .leading, spacing: 16) {
            Text("Never miss a birthday").font(.largeTitle.bold())
            Text("Gontacts needs notification permissions to remind you about the birthdays and anniversaries in your contacts.")
                .font(.title3).foregroundStyle(.secondary)

            // A birthday today, drawn the way the Events list shows it.
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hana Ito").font(.body.weight(.semibold)).foregroundStyle(.tint)
                    HStack(spacing: 8) {
                        Image(systemName: "birthday.cake").foregroundStyle(.pink).imageScale(.small)
                        Text("Birthday · turns 34").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Text("Today")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.accentColor, in: .capsule)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color.accentColor.opacity(0.16), in: .rect(cornerRadius: 24))
            .padding(.top, 8)
            .accessibilityElement(children: .combine)

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
