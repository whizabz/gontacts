import SwiftUI
import UIKit

extension Color {
    /// A colour that switches with light and dark appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

/// The widget look: the app's indigo accent, tinted initials, flat cards with a soft edge.
enum Theme {
    static let card = Color(light: 0xFFFFFF, dark: 0x1C1C1F)
    static let accent = Color(light: 0x4F46E5, dark: 0x8B85FF)
    static let accentOnAccent = Color(light: 0xFFFFFF, dark: 0x111113)
    static let secondary = Color(light: 0x6B6B76, dark: 0x9A9AA5)
    static let line = Color(light: 0xE6E6EB, dark: 0x2C2C31)
    static let edge = Color(light: 0xFFFFFF, dark: 0xFFFFFF).opacity(0.12)
    static let cake = Color(light: 0xD6336C, dark: 0xF472B6)
    static let glass = Color(light: 0xC2410C, dark: 0xFB923C)

    /// indigo, pink, green, orange, teal
    static let palette: [Color] = [
        Color(light: 0x4F46E5, dark: 0xA5A0FF),
        Color(light: 0xBE185D, dark: 0xF472B6),
        Color(light: 0x237A38, dark: 0x5FD37D),
        Color(light: 0xC2410C, dark: 0xFB923C),
        Color(light: 0x0E7490, dark: 0x38BDF8),
    ]
}
