import SwiftUI
import UIKit

/// A one-shot confetti cannon: two bursts shoot up and inward from the bottom corners, slow down fast,
/// then flutter back down and out of the bottom of the screen. Pieces sit at different depths: far ones are
/// small and soft, near ones are big and blurred.
/// Purely decorative: hidden from accessibility and skipped entirely under Reduce Motion by callers.
///
/// Every piece's position is a closed-form function of time (launch speed with air drag, plus gravity),
/// so there is no per-frame state to integrate and nothing to drift if a frame is dropped.
struct ConfettiView: View {
    enum Shape { case rect, circle, triangle }

    struct Piece {
        let depth: Depth
        let fromRight: Bool
        let delay: Double       // a few tens of ms, so the burst isn't one solid clump
        let vx: CGFloat         // launch velocity, pt/s (y is up-negative)
        let vy: CGFloat
        let gravity: Double
        let sway: CGFloat       // side-to-side flutter once it's falling
        let swaySpeed: Double
        let phase: Double
        let size: CGSize
        let spin: Double        // rotation, rad/s
        let flip: Double        // how fast it tumbles end over end
        let color: Color
        let shape: Shape
    }

    private static let colors: [Color] = [.indigo, .pink, .orange, .yellow, .green, .blue, .red, .purple, .teal]
    private static let perCorner = 70
    private static let drag = 3.0           // 1/s: how quickly launch speed bleeds off
    private static let gravity = 700.0      // pt/s²; with the drag, pieces settle at about 230 pt/s
    private static let duration = 6.5       // by then everything has fallen off the bottom, even on a tall iPad

    static func makePieces() -> [Piece] {
        (0..<(perCorner * 2)).map { i in
            let depth = Depth.random()
            let angle = Double.random(in: 52...84) * .pi / 180      // from the horizontal, aimed inward
            let speed = Double.random(in: 1000...2300) * Double(depth.speed)
            let shape: Shape = [.rect, .rect, .rect, .circle, .triangle].randomElement()!
            let w = CGFloat.random(in: 6...11) * depth.scale
            let size: CGSize = switch shape {
            case .rect: CGSize(width: w, height: w * 1.7)
            case .circle, .triangle: CGSize(width: w, height: w)
            }
            let fromRight = i % 2 == 1
            return Piece(depth: depth, fromRight: fromRight, delay: .random(in: 0...0.12),
                         vx: CGFloat(cos(angle) * speed) * (fromRight ? -1 : 1), vy: -CGFloat(sin(angle) * speed),
                         gravity: gravity * Double(depth.speed),
                         sway: .random(in: 8...26) * depth.scale, swaySpeed: .random(in: 2...5), phase: .random(in: 0...(2 * .pi)),
                         size: size, spin: .random(in: -9...9), flip: .random(in: 4...12),
                         color: colors.randomElement()!, shape: shape)
        }
    }

    let scene: CelebrationScene
    let part: CelebrationPart
    @State private var finished = false

    var body: some View {
        ZStack {
            ForEach(part.depths, id: \.self) { depth in
                DepthCanvas(depth: depth, start: scene.start, paused: finished) { layer, t, size in
                    drawPieces(&layer, depth: depth, t: t, size: size)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            // Fire: a thump as the cannons go off, then a light tap for the pop.
            // The generators are warmed up now, well before they are needed.
            let haptics = part == .front && !scene.silent ? Haptics() : nil
            try? await Task.sleep(for: .seconds(CelebrationScene.startDelay))
            if let haptics {
                haptics.thump()
                try? await Task.sleep(for: .seconds(0.07))
                haptics.tap(0.7)
                try? await Task.sleep(for: .seconds(Self.duration - 0.07))
            } else {
                try? await Task.sleep(for: .seconds(Self.duration))
            }
            finished = true
        }
    }

    private func drawPieces(_ layer: inout GraphicsContext, depth: Depth, t: Double, size: CGSize) {
        let k = Self.drag
        for p in scene.confetti[depth.rawValue] {
            let lt = t - p.delay
            guard lt > 0 else { continue }
            let e = exp(-k * lt)
            let settle = 1 - e
            let x0: CGFloat = p.fromRight ? size.width : 0
            let x = x0 + p.vx * CGFloat(settle / k) + p.sway * CGFloat(sin(lt * p.swaySpeed + p.phase) * settle)
            let y = size.height + CGFloat(p.gravity / k * lt) + (p.vy - CGFloat(p.gravity / k)) * CGFloat(settle / k)
            // Once it is falling and below the screen it is gone for good.
            guard y < size.height + 40 || lt < 0.6 else { continue }

            var c = layer
            c.translateBy(x: x, y: y)
            c.rotate(by: .radians(p.phase + lt * p.spin))
            c.scaleBy(x: 1, y: max(0.15, abs(cos(lt * p.flip + p.phase))))
            let r = CGRect(x: -p.size.width / 2, y: -p.size.height / 2, width: p.size.width, height: p.size.height)
            let path: Path = switch p.shape {
            case .rect: Path(roundedRect: r, cornerRadius: 1.5)
            case .circle: Path(ellipseIn: r)
            case .triangle: Path { $0.move(to: CGPoint(x: r.midX, y: r.minY)); $0.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); $0.addLine(to: CGPoint(x: r.minX, y: r.maxY)); $0.closeSubpath() }
            }
            c.fill(path, with: .color(p.color))
        }
    }
}
