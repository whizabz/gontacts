import SwiftUI

/// A one-shot confetti burst that falls from the top of its container.
/// Purely decorative: hidden from accessibility and skipped entirely under Reduce Motion by callers.
struct ConfettiView: View {
    private struct Piece {
        let x: CGFloat        // 0...1 across the width
        let delay: Double
        let fall: CGFloat     // base speed, pt/s
        let drift: CGFloat    // horizontal sway amplitude
        let phase: Double
        let size: CGSize
        let spin: Double
        let color: Color
        let round: Bool
    }

    private static let colors: [Color] = [.indigo, .pink, .orange, .yellow, .green, .blue, .red]
    private static let duration: Double = 4.5

    private let pieces: [Piece] = (0..<90).map { _ in
        let round = Int.random(in: 0..<4) == 0
        let w = CGFloat.random(in: 6...10)
        return Piece(x: .random(in: 0...1), delay: .random(in: 0...0.9), fall: .random(in: 220...420), drift: .random(in: 8...30),
                     phase: .random(in: 0...(2 * .pi)), size: round ? CGSize(width: w, height: w) : CGSize(width: w, height: w * 1.8),
                     spin: .random(in: -6...6), color: colors.randomElement()!, round: round)
    }

    @State private var start = Date()
    @State private var finished = false

    var body: some View {
        TimelineView(.animation(paused: finished)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in pieces {
                    let lt = t - p.delay
                    guard lt > 0 else { continue }
                    let y = -20 + CGFloat(lt) * p.fall
                    guard y < size.height + 20 else { continue }
                    let x = p.x * size.width + sin(lt * 2.2 + p.phase) * p.drift
                    let fade = max(0, min(1, (Self.duration - t) / 1.2))
                    var c = context
                    c.opacity = fade
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(lt * p.spin))
                    let rect = CGRect(x: -p.size.width / 2, y: -p.size.height / 2, width: p.size.width, height: p.size.height)
                    c.fill(p.round ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 2), with: .color(p.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            start = Date()
            try? await Task.sleep(for: .seconds(Self.duration))
            finished = true
        }
    }
}
