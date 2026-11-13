import SwiftUI

extension View {
    /// On iPad a sheet is a floating form sheet, and swiping down on it dismisses it by accident. Keep it open there
    /// (the Cancel / Done buttons still close it); on iPhone the swipe-down gesture stays.
    func iPadSheetStaysOpen() -> some View { modifier(IPadSheetStaysOpen()) }
}

private struct IPadSheetStaysOpen: ViewModifier {
    // The device idiom, not the size class: a form sheet on iPad reports a compact width.
    func body(content: Content) -> some View { content.interactiveDismissDisabled(UIDevice.current.userInterfaceIdiom == .pad) }
}

enum Platform {
    /// True when running as the Mac Catalyst app.
    static var isMac: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #else
        false
        #endif
    }
}

extension Color {
    /// Mac window: the sidebar sits a shade lighter than the main pane so the two read as separate panels.
    static let macSidebar = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.17, alpha: 1) : UIColor(white: 0.93, alpha: 1) })
    static let macDetail = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.12, alpha: 1) : UIColor(white: 1, alpha: 1) })
}
