import SwiftUI

/// The whole app in one screen, like iOS Contacts: a segmented control at the top switches between the
/// Contacts list and the Events list; Settings opens from the toolbar.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false
    /// True when iPadOS draws the sidebar as a floating panel (then the detail is a matching floating card).
    @State private var sidebarFloats = true
    @State private var showNew = false
    @State private var query = ""
    @State private var pendingShare: URL?

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        @Bindable var model = model
        Group {
            if sizeClass == .regular { regularLayout } else { compactLayout }
        }
        .sheet(isPresented: $model.showCards, onDismiss: { model.cardRequest = nil }) {
            NavigationStack { ContactCardsView(inSheet: true) }.iPadSheetStaysOpen()
        }
        .sheet(item: $model.shareRequest, onDismiss: {
            if let url = pendingShare { pendingShare = nil; ShareSheet.present(url) }
        }) { contact in
            ShareContactView(contact: contact) { pendingShare = $0 }.iPadSheetStaysOpen()
        }
        .confirmationDialog("Delete this contact?", isPresented: Binding(get: { model.deleteRequest != nil }, set: { if !$0 { model.deleteRequest = nil } }), titleVisibility: .visible, presenting: model.deleteRequest) { contact in
            Button("Delete \(contact.displayName)", role: .destructive) {
                Task {
                    do {
                        try await model.store.delete(contact)
                        if model.contactsSelection == contact.id { model.contactsSelection = nil }
                    } catch { model.store.errorMessage = error.localizedDescription }
                }
            }
        } message: { _ in Text("This also deletes it from Google Contacts.") }
        .sheet(isPresented: $showSettings) { SettingsView().iPadSheetStaysOpen() }
        .sheet(isPresented: $showNew) {
            EditContactView(contact: .blank()) { saved in
                model.homeMode = .contacts
                model.contactsSelection = saved.id
            }
            .iPadSheetStaysOpen()
        }
    }

    // MARK: Layouts

    /// iPhone and narrow windows: one split view, with a segmented control switching Contacts and Events.
    private var compactLayout: some View {
        @Bindable var model = model
        return NavigationSplitView {
            list(for: model.homeMode)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("View", selection: $model.homeMode) {
                            ForEach(HomeMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(minWidth: 250, maxWidth: 320)
                    }
                    ToolbarItem(placement: .topBarLeading) { settingsButton }
                    // As in iOS Contacts: the search field in the bottom bar with the add button beside it.
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    ToolbarItem(placement: .bottomBar) { newButton }
                }
        } detail: {
            detail(for: model.homeMode)
        }
    }

    /// iPad and wide windows: a plain two-pane layout like Cardhop. The same Contacts/Events switcher as on iPhone spans
    /// the top of the list column with the sort control under it; Settings, search and add sit in a bottom bar.
    private var regularLayout: some View {
        @Bindable var model = model
        return NavigationSplitView {
            list(for: model.homeMode, sortInToolbar: false, searchable: false)
                .modifier(SidebarBars(query: $query, mode: model.homeMode, topPadding: sidebarFloats ? 24 : 20,
                                      onSettings: { showSettings = true }, onNew: { showNew = true }))
                // Exactly the iPhone control: the toolbar's segmented picker, with the same glass treatment.
                .background {
                    // Where the sidebar sits tells us if iPadOS floats it as a panel or runs it edge to edge.
                    GeometryReader { proxy in
                        Color.clear.onChange(of: proxy.frame(in: .global).minX, initial: true) { _, x in sidebarFloats = x > 4 }
                    }
                    .ignoresSafeArea()
                }
                .toolbar(removing: .sidebarToggle)
                .modifier(MacScrollEdge())
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("View", selection: $model.homeMode) {
                            ForEach(HomeMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 296)
                        .padding(.top, sidebarFloats ? 34 : 14)
                    }
                }
        } detail: {
            if sidebarFloats {
                // A rounded card in the same glass as the floating sidebar panel.
                detail(for: model.homeMode, embedded: true)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    // The card is a background that ignores the safe area, so a navigation bar can't change its height.
                    .background {
                        Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 30))
                            .padding(.leading, 12).padding(.trailing, 12).padding(.top, 32).padding(.bottom, 11)
                            .ignoresSafeArea(edges: .vertical)
                    }
                    .background(Color(.systemGroupedBackground))
            } else {
                // The sidebar runs edge to edge, so the detail is a plain full-height pane too.
                detail(for: model.homeMode, embedded: true)
            }
        }
    }

    private func list(for mode: HomeMode, sortInToolbar: Bool = true, searchable: Bool = true) -> some View {
        Group {
            switch mode {
            case .contacts:
                if query.isEmpty { ContactsList(showsSortInToolbar: sortInToolbar) } else { ContactSearchResults(query: query) }
            case .events:
                EventsList(query: query)
            }
        }
        // Search lives here, not in either list, so it stays put on both Contacts and Events.
        .modifier(OptionalSearch(enabled: searchable, query: $query, prompt: mode == .events ? "Search events" : "Search contacts"))
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .toolbarTitleDisplayMode(.inline)
    }

    private func detail(for mode: HomeMode, embedded: Bool = false) -> some View {
        NavigationStack {
            switch mode {
            case .contacts:
                if let id = model.contactsSelection {
                    ContactDetailView(contactID: id, embedded: embedded)
                } else {
                    ContentUnavailableView("Select a Contact", systemImage: "person.crop.circle")
                }
            case .events:
                if let selection = model.eventsSelection {
                    // List selection is the occurrence id ("contactID|event|time"); the contact id is its first part.
                    ContactDetailView(contactID: String(selection.prefix { $0 != "|" }), embedded: embedded)
                } else {
                    ContentUnavailableView("Select an Event", systemImage: "calendar")
                }
            }
        }
    }

    private var settingsButton: some View {
        Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
    }

    private var newButton: some View {
        Button { showNew = true } label: { Label("New Contact", systemImage: "plus") }
    }
}

/// Count and sort control under the Contacts/Events switcher on iPad.
private struct ContactsListHeader: View {
    @Environment(AppModel.self) private var model
    @AppStorage("contacts.sort") private var sort = ContactSort.name

    var body: some View {
        HStack {
            Text("\(model.store.contacts.count) Contacts").font(.footnote).foregroundStyle(.secondary)
            Spacer()
            Menu {
                Picker("Sort By", selection: $sort) {
                    ForEach(ContactSort.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                Label(sort.title, systemImage: "arrow.up.arrow.down").font(.footnote.weight(.semibold))
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
    }
}

private struct OptionalSearch: ViewModifier {
    let enabled: Bool
    @Binding var query: String
    let prompt: String

    func body(content: Content) -> some View {
        if enabled { content.searchable(text: $query, prompt: Text(prompt)) } else { content }
    }
}

/// Settings, search and add in one row at the bottom of the iPad list column.
private struct SidebarBottomBar: View {
    @Binding var query: String
    let prompt: String
    let onSettings: () -> Void
    let onNew: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSettings) {
                Image(systemName: "gearshape").font(.title3).frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Settings")

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(prompt, text: $query)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.plain).accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .glassEffect(.regular, in: .capsule)

            Button(action: onNew) {
                Image(systemName: "plus").font(.title3.weight(.semibold)).foregroundStyle(.white).frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)
            .accessibilityLabel("New Contact")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}


/// On the Mac the translucent band under the toolbar grows into a tall blur as the list scrolls; hide the scroll-edge effects there.
private struct MacScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if Platform.isMac {
            // No system toolbar background (it renders lighter than the list); `SidebarBars` fills the area instead.
            content
                .scrollEdgeEffectHidden(true, for: .all)
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        } else { content }
    }
}

/// The sidebar's header (sort control) and bottom bar (settings, search, add). On iPad they're system bars that blur
/// content under them; on the Mac that blur covered the whole list, so there they are plain insets.
private struct SidebarBars: ViewModifier {
    @Binding var query: String
    let mode: HomeMode
    let topPadding: CGFloat
    let onSettings: () -> Void
    let onNew: () -> Void

    @ViewBuilder private var header: some View {
        if mode == .contacts { ContactsListHeader().padding(.top, topPadding).padding(.bottom, 4) }
    }
    private var bottom: some View {
        SidebarBottomBar(query: $query, prompt: "Search", onSettings: onSettings, onNew: onNew)
    }

    func body(content: Content) -> some View {
        if Platform.isMac {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    // The fill runs up behind the toolbar, so the Contacts/Events control sits on the list's own colour.
                    header.background(Color(.systemBackground).ignoresSafeArea(edges: .top))
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { bottom.background(Color(.systemBackground)) }
        } else {
            content
                .safeAreaBar(edge: .top, spacing: 0) { header }
                .safeAreaBar(edge: .bottom, spacing: 0) { bottom }
        }
    }
}
