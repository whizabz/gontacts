import SwiftUI

struct EventsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selection: String?
    @State private var offsetY: CGFloat = 0
    @State private var anchorOffsetY: CGFloat?

    /// Leaves room for the navigation bar so the target section header isn't hidden under it.
    private static let anchorPoint = UnitPoint(x: 0.5, y: 0.02)

    private var sections: [EventSection] {
        let today = Calendar.current.startOfDay(for: .now)
        let start = Calendar.current.date(byAdding: .month, value: -12, to: today)!
        let end = Calendar.current.date(byAdding: .month, value: 12, to: today)!
        let all = EventTimeline.occurrences(for: model.store.contacts, from: start, to: end)
        return EventTimeline.sections(from: all, today: today)
    }

    var body: some View {
        let sections = sections
        let anchor = EventTimeline.anchorID(in: sections)

        NavigationSplitView {
            ScrollViewReader { proxy in
                List(selection: $selection) {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.occurrences) { o in
                                NavigationLink(value: o.contactID) { EventRow(occurrence: o) }
                            }
                        } header: {
                            HStack {
                                Text(section.title).foregroundStyle(section.role == .today ? Color.accentColor : .secondary)
                                Spacer()
                                if let trailing = section.trailing { Text(trailing).font(.footnote).textCase(nil) }
                            }
                            .id(section.id)
                        }
                    }
                }
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, new in offsetY = new }
                .overlay(alignment: .bottomTrailing) {
                    if showTodayButton, let anchor {
                        Button {
                            withAnimation(.smooth) { proxy.scrollTo(anchor, anchor: Self.anchorPoint) }
                        } label: {
                            Label("Today", systemImage: pointsDown ? "arrow.down" : "arrow.up").font(.headline)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .padding(.horizontal, 16)
                        // The floating tab bar sits over content on iPhone, so lift the button above it.
                        .padding(.bottom, sizeClass == .compact ? 88 : 16)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.smooth, value: showTodayButton)
                .task(id: anchor) {
                    guard let anchor else { return }
                    anchorOffsetY = nil
                    try? await Task.sleep(for: .milliseconds(50))
                    proxy.scrollTo(anchor, anchor: Self.anchorPoint)
                    // Remember where "today" landed so we can tell when the user has scrolled away from it.
                    try? await Task.sleep(for: .milliseconds(700))
                    anchorOffsetY = offsetY
                }
            }
            .navigationTitle("Events")
            .overlay {
                if sections.isEmpty {
                    ContentUnavailableView("No Events", systemImage: "calendar", description: Text("Add birthdays and anniversaries to your contacts and they'll show up here."))
                }
            }
        } detail: {
            NavigationStack {
                if let selection {
                    // List selection is the occurrence id ("contactID|event|time"); the contact id is its first part.
                    ContactDetailView(contactID: String(selection.prefix { $0 != "|" }))
                } else {
                    ContentUnavailableView("Select an Event", systemImage: "calendar")
                }
            }
        }
    }

    /// Shown once the list has been scrolled well away from where it opened.
    private var showTodayButton: Bool {
        guard let anchorOffsetY else { return false }
        return abs(offsetY - anchorOffsetY) > 350
    }

    private var pointsDown: Bool {
        guard let anchorOffsetY else { return true }
        return offsetY < anchorOffsetY
    }
}

struct EventRow: View {
    let occurrence: EventOccurrence

    private static let dayStyle = Date.FormatStyle().weekday(.abbreviated).day()

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(occurrence.contactName).font(.body.weight(.semibold))
                EventLine(kind: occurrence.event.kind, text: occurrence.detail)
            }
            Spacer(minLength: 8)
            Text(occurrence.date.formatted(Self.dayStyle))
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
