import SwiftUI

/// Soft, blurred confetti behind the content of a widget. Pieces are close (sharp, bright) or far (blurred, faint), all kept light so they don't fight the text
/// and gather toward the top right and the lower left edge, so text stays readable.
struct ConfettiLayer: View {
    enum Density: Int { case none = 0, light = 8, rich = 14 }

    var density: Density
    var seed: UInt64 = 7

    private struct Piece: Identifiable {
        let id: Int
        let x, y: Double          // fractions of the widget
        let w, h: CGFloat
        let angle: Double
        let blur: CGFloat
        let opacity: Double
        let color: Int
        let kind: Int             // 0 rect, 1 dot, 2 triangle, 3 streamer
    }

    private var pieces: [Piece] {
        var rng = SplitMix(seed: seed)
        return (0..<density.rawValue).map { i in
            let kind = i % 4
            let depth = Double(i % 3)             // 0 near, 1 mid, 2 far
            // Most pieces in the top-right region, the rest along the lower left.
            let top = i % 4 != 3
            let x = top ? 0.48 + rng.next() * 0.46 : 0.10 + rng.next() * 0.22
            let y = top ? 0.04 + rng.next() * 0.5 : 0.62 + rng.next() * 0.32
            let size: CGFloat = [16, 9, 13, 24][kind] - CGFloat(depth) * 2
            return Piece(id: i, x: x, y: y,
                         w: size, h: [7, 9, 13, 4][kind] - (kind == 0 ? CGFloat(depth) : 0),
                         angle: rng.next() * 90 - 45,
                         blur: [1.5, 3, 5][Int(depth)],
                         opacity: [0.85, 0.6, 0.4][Int(depth)] * (top ? 1 : 0.7) * 0.5,
                         color: i % Theme.palette.count,
                         kind: kind)
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { p in
                    shape(p)
                        .foregroundStyle(Theme.palette[p.color])
                        .frame(width: p.w, height: p.kind == 1 ? p.w : p.h)
                        .rotationEffect(.degrees(p.angle))
                        .blur(radius: p.blur)
                        .opacity(p.opacity)
                        .position(x: p.x * geo.size.width, y: p.y * geo.size.height)
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func shape(_ p: Piece) -> some View {
        switch p.kind {
        case 1: Circle()
        case 2: TriangleShape()
        case 3: Capsule()
        default: RoundedRectangle(cornerRadius: 2)
        }
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A tiny deterministic random generator, so confetti sits in the same places every time.
private struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return Double(z % 10_000) / 10_000
    }
}
