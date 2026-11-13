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
