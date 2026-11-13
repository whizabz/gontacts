import Foundation

extension Contact {
    /// The contact as readable text for pasting into a message or note. Empty fields are left out.
    var plainText: String {
        var lines: [String] = [displayName]
        if !nickname.isEmpty && nickname != displayName { lines.append("“\(nickname)”") }
        if !subtitle.isEmpty { lines.append(subtitle) }

        func block(_ items: [LabeledValue]) {
            let items = items.filter { !$0.value.isEmpty }
            guard !items.isEmpty else { return }
            lines.append("")
            lines += items.map { "\($0.label.displayLabel): \($0.value)" }
        }
        block(phones)
        block(emails)
        for a in addresses where !a.isEmpty {
            lines.append("")
            lines.append("\(a.label.displayLabel):")
            lines.append(a.formatted)
        }
        block(urls)
        block(ims)
        block(relations)
        block(customFields)
        if !events.isEmpty {
            lines.append("")
            lines += events.map { "\($0.displayTitle): \($0.date.formatted())" }
        }
        if !notes.isEmpty {
            lines.append("")
            lines.append(notes)
        }
        return lines.joined(separator: "\n")
    }
}
