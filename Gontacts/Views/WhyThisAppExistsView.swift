import SwiftUI

/// Why the app exists: the same year-less birthday is stored differently by Apple and Google Contacts.
///
/// This is the one and only version of the screen. Onboarding and Settings both show it, so editing the text or the
/// cards here changes both. Onboarding passes `onContinue` to get a "Got it" button; Settings leaves it out.
struct WhyThisAppExistsView: View {
    var onContinue: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Why Gontacts?").font(.largeTitle.bold())
                    Text("Apple and Google store year-less dates differently. This causes issues with contacts stored in Google Contacts. Gontacts saves the day by speaking Google's language.")
                        .font(.title3).foregroundStyle(.secondary)
                    ComparisonCards(compact: true).padding(.top, 4)
                }
                .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            if let onContinue {
                Button(action: onContinue) {
                    Text("Got it").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent).controlSize(.extraLarge)
                .padding(.horizontal, 24).padding(.bottom, 12)
                .frame(maxWidth: 560)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The same sample contact as Apple Contacts and Google Contacts store it, with the stored form of the birthday
/// highlighted. `compact` tightens the cards to fit alongside other content (onboarding).
struct ComparisonCards: View {
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 24 : 18) {
            // Each card moves and turns a little as the phone is tilted, by different amounts so they seem to sit
            // at different depths.
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
                .tiltParallax(travel: 8)

            // This card has no flag line under its date, so it gets the same height as the Apple one.
            ContactCardSample(compact: compact, extraBottom: 18, logo: AnyView(Image("GoogleG").resizable().scaledToFit()),
                              birthday: AnyView(
                                HStack(alignment: .firstTextBaseline, spacing: 14) {
                                    Text("--1126").font(.system(.footnote, design: .monospaced)).fontWeight(.semibold)
                                        .dateHighlight(delay: 0.9)
                                    Text("(26 November)").font(.footnote).foregroundStyle(.secondary)
                                }))
                .tiltParallax(travel: 14)
        }
    }
}

/// A rolodex-style card for the sample contact. `logo` is the platform mark, drawn faintly in the top right corner.
private struct ContactCardSample: View {
    var compact = false
    /// Extra space at the bottom, so cards with fewer lines can match a taller one.
    var extraBottom: CGFloat = 0
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
        .padding(.horizontal, 16).padding(.top, compact ? 14 : 16).padding(.bottom, 4 + extraBottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The card itself has the punch holes cut out of it, so whatever is behind shows through them.
        .background {
            PunchedCardShape().fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        }
        // Faint platform logo, like a watermark.
        .overlay(alignment: .topTrailing) {
            logo.frame(width: 22, height: 22).foregroundStyle(.secondary).opacity(0.35).padding(16)
        }
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

/// A rounded card with a half-round punch hole in the middle of each side, like a rolodex card. Drawn with the
/// holes taken out of the outline, so they are real cutouts, not painted circles.
private struct PunchedCardShape: Shape {
    var cornerRadius: CGFloat = 22
    var holeRadius: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var holes = Path()
        for x in [rect.minX, rect.maxX] {
            holes.addEllipse(in: CGRect(x: x - holeRadius, y: rect.midY - holeRadius, width: holeRadius * 2, height: holeRadius * 2))
        }
        // Subtract (not even-odd fill): the half of each circle outside the card must not be filled in.
        return Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous).subtracting(holes)
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
