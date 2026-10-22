import SwiftUI
import UIKit

/// "Share Contact": choose which fields go into the vCard, then hand it to the iOS share sheet.
/// (iOS has no public version of this screen, so it's built from system pieces.)
struct ShareContactView: View {
    @Environment(\.dismiss) private var dismiss
    let contact: Contact
    /// Called with the .vcf to share; the caller opens the iOS share sheet once this screen has closed.
    let onShare: (URL) -> Void

    @State private var chosen: Set<ShareField>

    init(contact: Contact, onShare: @escaping (URL) -> Void) {
        self.contact = contact
        self.onShare = onShare
        // Like iOS: name, phones and emails start ticked; the rest is opt-in.
        var start: Set<ShareField> = []
        if !contact.displayName.isEmpty { start.insert(.name) }
        contact.phones.forEach { start.insert(.phone($0.id)) }
        contact.emails.forEach { start.insert(.email($0.id)) }
        _chosen = State(initialValue: start)
    }

    private struct Row: Identifiable {
        let field: ShareField
        let label: String
        let value: String
        var id: ShareField { field }
    }

    private var groups: [[Row]] {
        var identity: [Row] = []
        let name = [contact.namePrefix, contact.givenName, contact.middleName, contact.familyName, contact.nameSuffix].filter { !$0.isEmpty }.joined(separator: " ")
        if !name.isEmpty { identity.append(Row(field: .name, label: "Name", value: name)) }
        if !contact.nickname.isEmpty { identity.append(Row(field: .nickname, label: "Nickname", value: contact.nickname)) }
        let company = [contact.organization, contact.department].filter { !$0.isEmpty }.joined(separator: " · ")
        if !company.isEmpty { identity.append(Row(field: .company, label: "Company", value: company)) }
        if !contact.jobTitle.isEmpty { identity.append(Row(field: .jobTitle, label: "Job title", value: contact.jobTitle)) }

        let phones = contact.phones.filter { !$0.value.isEmpty }.map { Row(field: .phone($0.id), label: $0.label.displayLabel, value: $0.value) }
        let emails = contact.emails.filter { !$0.value.isEmpty }.map { Row(field: .email($0.id), label: $0.label.displayLabel, value: $0.value) }
        let addresses = contact.addresses.filter { !$0.isEmpty }.map {
            Row(field: .address($0.id), label: $0.label.displayLabel, value: $0.formatted.replacingOccurrences(of: "\n", with: ", "))
        }
        let urls = contact.urls.filter { !$0.value.isEmpty }.map { Row(field: .url($0.id), label: $0.label.displayLabel, value: $0.value) }
        let dates = contact.events.map { Row(field: .event($0.id), label: $0.displayTitle, value: $0.date.formatted()) }
        var notes: [Row] = []
        if !contact.notes.isEmpty { notes.append(Row(field: .notes, label: "Notes", value: contact.notes)) }

        return [identity, phones, emails, addresses, urls, dates, notes].filter { !$0.isEmpty }
    }

    private var allFields: Set<ShareField> { Set(groups.flatMap { $0.map(\.field) }) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, rows in
                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                                if index > 0 { Divider().padding(.leading, 56) }
                                fieldRow(row)
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Share Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { share() }.disabled(chosen.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(chosen == allFields ? "Deselect All Fields" : "Select All Fields") {
                        chosen = chosen == allFields ? [] : allFields
                    }
                }
            }
        }
    }

    private func fieldRow(_ row: Row) -> some View {
        let on = chosen.contains(row.field)
        return Button {
            if on { chosen.remove(row.field) } else { chosen.insert(row.field) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(on ? Color.accentColor : Color.accentColor.opacity(0.7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.label).font(.subheadline).foregroundStyle(.secondary)
                    Text(row.value).foregroundStyle(.primary).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func share() {
        guard let url = try? contact.keeping(chosen).writeVCardFile() else { return }
        onShare(url)
        dismiss()
    }
}

/// Opens the standard iOS share sheet over whatever is on screen.
@MainActor
enum ShareSheet {
    static func present(_ url: URL) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              var top = scene.keyWindow?.rootViewController else { return }
        while let next = top.presentedViewController { top = next }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = top.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.maxX - 40, y: 60, width: 1, height: 1)
        top.present(sheet, animated: true)
    }
}
