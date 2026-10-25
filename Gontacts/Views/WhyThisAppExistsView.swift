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

                ComparisonCards()
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 28)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The same sample contact as Apple Contacts and Google Contacts store it, with the stored form of the birthday
/// highlighted. `compact` tightens the cards to fit alongside other content (onboarding).
struct ComparisonCards: View {
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 12 : 18) {
            ContactCardSample(compact: compact, logo: AnyView(Image(systemName: "apple.logo").resizable().scaledToFit()),
                              birthday: AnyView(
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                                        Text("1604-11-26").font(.system(.footnote, design: .monospaced)).fontWeight(.semibold)
                                            .dateHighlight(delay: 0.5)
                                        Text("(26 November)").font(.footnote).foregroundStyle(.secondary)
                                    }
                                    Text("X-APPLE-OMIT-YEAR=1604").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                                }))

            ContactCardSample(compact: compact, logo: AnyView(Image("GoogleG").resizable().scaledToFit()),
                              birthday: AnyView(
                                HStack(alignment: .firstTextBaseline, spacing: 14) {
                                    Text("--1126").font(.system(.footnote, design: .monospaced)).fontWeight(.semibold)
                                        .dateHighlight(delay: 0.9)
                                    Text("(26 November)").font(.footnote).foregroundStyle(.secondary)
                                }))
        }
    }
}

/// A rolodex-style card for the sample contact. `logo` is the platform mark, drawn faintly in the top right corner.
private struct ContactCardSample: View {
    var compact = false
    let logo: AnyView
    let birthday: AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("H").font(compact ? .headline : .title2.weight(.semibold)).foregroundStyle(.tint)
                    .frame(width: compact ? 40 : 56, height: compact ? 40 : 56)
                    .background(Color.accentColor.opacity(0.12), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hana Ito").font(compact ? .headline : .title3.bold())
                    Text("Product Designer · Lumen Studio").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, compact ? 8 : 12)

            row("mobile") { Text(verbatim: "+81 90 5550 0142") }
            row("work") { Text(verbatim: "hana@lumen.example") }
            row("home") { Text(verbatim: "2-14-5 Minami-Aoyama, Tokyo") }
            row("birthday") { birthday }
        }
        .font(compact ? .footnote : .subheadline)
        .padding(.horizontal, 16).padding(.top, compact ? 14 : 16).padding(.bottom, 4)
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
            .padding(.vertical, compact ? 6 : 9)
        }
    }
}

// MARK: - Animated highlight

/// A highlighter-style marker behind the birthday: it sweeps in from the left, then pulses a few times to draw the
/// eye to how the two cards store the same date differently. Stays still when Reduce Motion is on.
private struct DateHighlight: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swept = false
    @State private var glow = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.highlighter)
                    .padding(.horizontal, -4).padding(.vertical, -3)
                    .scaleEffect(x: swept || reduceMotion ? 1 : 0, anchor: .leading)
                    .opacity(glow ? 0.55 : 1)
            }
            .onAppear {
                guard !reduceMotion else { swept = true; return }
                withAnimation(.easeOut(duration: 0.7).delay(delay)) { swept = true }
                withAnimation(.easeInOut(duration: 0.9).delay(delay + 0.8).repeatCount(5, autoreverses: true)) { glow = true }
            }
    }
}

extension View {
    fileprivate func dateHighlight(delay: Double) -> some View { modifier(DateHighlight(delay: delay)) }
}

private extension Color {
    /// Yellowish orange on light backgrounds; a warmer, dimmer amber on dark so it glows without glaring.
    static let highlighter = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.72, blue: 0.22, alpha: 0.42)
            : UIColor(red: 1.0, green: 0.69, blue: 0.13, alpha: 0.42)
    })
}
