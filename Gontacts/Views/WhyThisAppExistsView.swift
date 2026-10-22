import SwiftUI

/// Explains why the app exists: the same year-less birthday is stored differently by Apple and Google Contacts.
struct WhyThisAppExistsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 32)).foregroundStyle(.tint)
                        .frame(width: 64, height: 64)
                        .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 20))
                    Text("Why This App Exists").font(.title.bold()).multilineTextAlignment(.center)
                }

                Text("Gontacts is mainly for people who keep Google Contacts as the one place for all their contacts, and who use it to store important dates, like birthdays and anniversaries, to use later. Apple Contacts has trouble saving dates to Google Contacts, and that is the reason this app exists.")
                    .font(.body).lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("The same contact, saved two ways")
                    .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)

                ContactCardSample(logo: AnyView(Image(systemName: "apple.logo").resizable().scaledToFit()),
                                  birthday: AnyView(
                                    VStack(alignment: .leading, spacing: 2) {
                                        (Text("1604-11-26").fontWeight(.semibold) + Text("  (26 November)").font(.footnote).foregroundStyle(.secondary))
                                        Text("X-APPLE-OMIT-YEAR=1604").font(.caption).foregroundStyle(.secondary)
                                    }.font(.system(.footnote, design: .monospaced))))

                ContactCardSample(logo: AnyView(Image("GoogleG").resizable().scaledToFit()),
                                  birthday: AnyView(
                                    (Text("--1126").font(.system(.footnote, design: .monospaced)).fontWeight(.semibold)
                                     + Text("  (26 November)").font(.footnote).foregroundStyle(.secondary))))

                VStack(spacing: 10) {
                    Note(symbol: "exclamationmark.circle", tint: .red) {
                        Text("Sync issue. ").bold().foregroundStyle(.red)
                            + Text("Google's ") + code("--1126")
                            + Text(" is vCard 4.0 shorthand inside a vCard 3.0 file. iOS can't parse that over CardDAV, so year-less birthdays vanish.")
                    }
                    Note(symbol: "checkmark.circle", tint: .green) {
                        Text("Gontacts keeps them. ").bold().foregroundStyle(.green)
                            + Text("It works with Google's own format, so those dates stay intact.")
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 28)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func code(_ s: String) -> Text {
        Text(s).font(.system(.footnote, design: .monospaced))
    }
}

/// A rolodex-style card for the sample contact. `logo` is the platform mark, drawn faintly in the top right corner.
private struct ContactCardSample: View {
    let logo: AnyView
    let birthday: AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("H").font(.title2.weight(.semibold)).foregroundStyle(.tint)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor.opacity(0.12), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hana Ito").font(.title3.bold())
                    Text("Product Designer · Lumen Studio").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 12)

            row("mobile") { Text(verbatim: "+81 90 5550 0142") }
            row("work") { Text(verbatim: "hana@lumen.example") }
            row("home") { Text(verbatim: "2-14-5 Minami-Aoyama, Tokyo") }
            row("birthday") { birthday }
        }
        .font(.subheadline)
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
        // Faint platform logo, like a watermark.
        .overlay(alignment: .topTrailing) {
            logo.frame(width: 22, height: 22).foregroundStyle(.secondary).opacity(0.35).padding(16)
        }
        // The notch on each side, as on a rolodex card.
        .overlay(alignment: .leading) { Circle().fill(Color(.systemGroupedBackground)).frame(width: 16, height: 16).offset(x: -8) }
        .overlay(alignment: .trailing) { Circle().fill(Color(.systemGroupedBackground)).frame(width: 16, height: 16).offset(x: 8) }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }

    private func row<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label).font(.footnote).foregroundStyle(.secondary).frame(width: 62, alignment: .leading)
                value()
                Spacer(minLength: 0)
            }
            .padding(.vertical, 9)
        }
    }
}

private struct Note<Content: View>: View {
    let symbol: String
    let tint: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.title3).foregroundStyle(tint)
            content().font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(tint.opacity(0.1), in: .rect(cornerRadius: 18))
    }
}
