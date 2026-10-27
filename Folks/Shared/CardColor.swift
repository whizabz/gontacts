import SwiftUI

/// The pastel tiles cards use, each a light background with a darker symbol colour.
struct CardColor {
    let background: Color
    let foreground: Color

    static let all: [CardColor] = [
        CardColor(background: Color(red: 0.878, green: 0.871, blue: 1.0), foreground: Color(red: 0.247, green: 0.239, blue: 0.659)),
        CardColor(background: Color(red: 0.804, green: 0.937, blue: 0.890), foreground: Color(red: 0.043, green: 0.361, blue: 0.267)),
        CardColor(background: Color(red: 1.0, green: 0.851, blue: 0.894), foreground: Color(red: 0.612, green: 0.114, blue: 0.278)),
        CardColor(background: Color(red: 1.0, green: 0.890, blue: 0.780), foreground: Color(red: 0.761, green: 0.255, blue: 0.047)),
        CardColor(background: Color(red: 0.812, green: 0.937, blue: 0.953), foreground: Color(red: 0.055, green: 0.455, blue: 0.565)),
        CardColor(background: Color(red: 1.0, green: 0.945, blue: 0.722), foreground: Color(red: 0.541, green: 0.353, blue: 0.0)),
        CardColor(background: Color(red: 1.0, green: 0.839, blue: 0.820), foreground: Color(red: 0.702, green: 0.149, blue: 0.118)),
        CardColor(background: Color(red: 0.925, green: 0.925, blue: 0.945), foreground: Color(red: 0.294, green: 0.294, blue: 0.333)),
    ]

    static func at(_ index: Int) -> CardColor { all[min(max(index, 0), all.count - 1)] }
}
