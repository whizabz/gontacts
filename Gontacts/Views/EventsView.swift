import SwiftUI

struct EventsView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: String?
    @State private var sections: [EventSection] = []
    /// Where the list is relative to "today". Only changes when it crosses a threshold, so scrolling doesn't re-render.
    @State private var relation: ScrollRelation = .atAnchor
    @State private var scrollTracker = ScrollTracker()
    @State private var scrollHandle = ScrollViewHandle.Box()

    enum ScrollRelation { case atAnchor, above, below }

    /// Plain reference so tracking the live offset never invalidates the view.
    final class ScrollTracker {
        var offsetY: CGFloat = 0
        var anchorOffsetY: CGFloat?
    }

    private static let anchorPoint = UnitPoint(x: 0.5, y: 0.02)
    private static let awayThreshold: CGFloat = 350

    private func jumpToToday(_ anchor: String, _ proxy: ScrollViewProxy) {
        // scrollTo is ignored while the list is still decelerating, so stop the fling first.
        scrollHandle.stopMomentum()
        DispatchQueue.main.async {
            withAnimation(.bouncy(duration: 0.75, extraBounce: 0.25)) { proxy.scrollTo(anchor, anchor: Self.anchorPoint) }
        }
    }

    private func buildSections() -> [EventSection] {
        let today = Calendar.current.startOfDay(for: .now)
        let start = Calendar.current.date(byAdding: .month, value: -12, to: today)!
        let end = Calendar.current.date(byAdding: .month, value: 12, to: today)!
        let all = EventTimeline.occurrences(for: model.store.contacts, from: start, to: end)
        return EventTimeline.sections(from: all, today: today)
    }

    var body: some View {
        let anchor = EventTimeline.anchorID(in: sections)

        NavigationSplitView {
            ScrollViewReader { proxy in
                List(selection: $selection) {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.occurrences) { o in
                                NavigationLink(value: o.contactID) { EventRow(occurrence: o, isToday: section.role == .today) }
                                    .listRowBackground(section.role == .today ? Color.accentColor.opacity(0.14) : nil)
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
                .background(ScrollViewHandle(box: scrollHandle))
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in scrollTracker.offsetY = y }
                .onScrollGeometryChange(for: ScrollRelation.self) { geo in
                    guard let a = scrollTracker.anchorOffsetY else { return .atAnchor }
                    let d = geo.contentOffset.y - a
                    return d < -Self.awayThreshold ? .above : d > Self.awayThreshold ? .below : .atAnchor
                } action: { _, new in relation = new }
                .overlay(alignment: .bottom) {
                    if relation != .atAnchor, let anchor {
                        // Fires on touch-down rather than on a completed tap: a touch during a fling is otherwise
                        // spent on stopping the scroll, which made the button feel dead until the list settled.
                        Label("Today", systemImage: relation == .above ? "arrow.down" : "arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .glassEffect(.regular.interactive(), in: .capsule)
                            .contentShape(.capsule)
                            .onLongPressGesture(minimumDuration: 0, maximumDistance: 40) { jumpToToday(anchor, proxy) }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { jumpToToday(anchor, proxy) }
                            .padding(.bottom, 12)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.smooth, value: relation)
                .onChange(of: model.tabReselected[.events] ?? 0) { _, _ in
                    if let anchor { jumpToToday(anchor, proxy) }
                }
                .task(id: anchor) {
                    guard let anchor else { return }
                    scrollTracker.anchorOffsetY = nil
                    try? await Task.sleep(for: .milliseconds(50))
                    proxy.scrollTo(anchor, anchor: Self.anchorPoint)
                    // Remember where "today" landed so we can tell when the user has scrolled away from it.
                    try? await Task.sleep(for: .milliseconds(700))
                    scrollTracker.anchorOffsetY = scrollTracker.offsetY
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
        .onChange(of: model.store.revision, initial: true) { _, _ in sections = buildSections() }
    }
}

struct EventRow: View {
    let occurrence: EventOccurrence
    var isToday = false

    private static let dayStyle = Date.FormatStyle().weekday(.abbreviated).day()

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(occurrence.contactName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isToday ? Color.accentColor : .primary)
                EventLine(kind: occurrence.event.kind, text: occurrence.detail)
            }
            Spacer(minLength: 8)
            if isToday {
                Text("Today")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Color.accentColor, in: .capsule)
            } else {
                Text(occurrence.date.formatted(Self.dayStyle))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
