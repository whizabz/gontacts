import SwiftUI
import UIKit

/// Balloons that rise from the bottom and float off the top, at three depths (small and soft far away,
/// big and blurred up close). Partway up, one of the middle balloons pops: a ring flashes, shreds of
/// latex fly out, and the balloons around it get knocked sideways and wobble back.
/// Purely decorative: hidden from accessibility and skipped entirely under Reduce Motion by callers.
///
/// As with the confetti, every position is a closed-form function of time, so nothing is integrated per frame.
struct BalloonsView: View {
    struct Balloon {
        let depth: Depth
        let x: CGFloat          // 0...1 across the width
        let delay: Double
        let speed: CGFloat      // rise, pt/s
        let sway: CGFloat
        let swaySpeed: Double
        let phase: Double
        let radius: CGFloat     // half the balloon's width
        let color: Color
        let pops: Bool
    }

    private static let colors: [Color] = [.pink, .orange, .yellow, .green, .teal, .blue, .purple, .red, .indigo]
    private static let maxDelay = 1.4
    private static let slowest: CGFloat = 150           // pt/s, for sizing the run time
    private static let pushRadius: CGFloat = 190

    /// One burst's randomness, rolled once per run so no two pops look alike.
    struct Pop {
        struct Shard {
            enum Kind { case strip, chunk, curl }
            let angle: Double       // direction it flies, radians
            let speed: Double       // pt/s
            let size: CGSize        // as a fraction of the balloon's radius
            let spin: Double        // rad/s
            let life: Double        // seconds until it has faded
            let gravity: Double
            let kind: Kind
        }

        /// The popper has risen this far up the screen (0 is the bottom) when it bursts.
        let height: CGFloat = .random(in: 0.38...0.6)
        let pushStrength: CGFloat = .random(in: 85...150)
        /// How big the flash grows, and its ragged outline.
        let flashReach: CGFloat = .random(in: 1.3...2.3)
        let flashShape: [CGFloat] = (0..<9).map { _ in .random(in: 0.7...1.3) }
        let shards: [Shard]

        init() {
            // Latex doesn't fly out evenly: a few lobes of shreds, with stragglers.
            let lobes = (0..<Int.random(in: 2...4)).map { _ in Double.random(in: 0...(2 * .pi)) }
            shards = (0..<Int.random(in: 9...19)).map { _ in
                let angle = Bool.random() ? lobes.randomElement()! + .random(in: -0.7...0.7) : .random(in: 0...(2 * .pi))
                let kind: Shard.Kind = [.strip, .strip, .chunk, .curl].randomElement()!
                let size: CGSize = switch kind {
                case .strip: CGSize(width: .random(in: 0.25...0.7), height: .random(in: 0.06...0.14))
                case .chunk: CGSize(width: .random(in: 0.14...0.3), height: .random(in: 0.12...0.26))
                case .curl: CGSize(width: .random(in: 0.3...0.6), height: .random(in: 0.2...0.4))
                }
                return Shard(angle: angle, speed: .random(in: 110...540), size: size, spin: .random(in: -16...16),
                             life: .random(in: 0.35...1.0), gravity: .random(in: 320...680), kind: kind)
            }
        }
    }

    static func makeBalloons() -> [Balloon] {
        let counts: [Depth: Int] = [.far: 5, .back: 5, .mid: 7, .near: 3]
        var all: [Balloon] = []
        for depth in Depth.allCases {
            let n = counts[depth]!
            for i in 0..<n {
                all.append(Balloon(depth: depth, x: (CGFloat(i) + .random(in: 0.15...0.85)) / CGFloat(n),
                                   delay: .random(in: 0...maxDelay),
                                   speed: .random(in: 190...300) * depth.speed,
                                   sway: .random(in: 8...22) * depth.scale, swaySpeed: .random(in: 1.2...2.4), phase: .random(in: 0...(2 * .pi)),
                                   radius: .random(in: 26...34) * depth.scale, color: colors.randomElement()!, pops: false))
            }
        }
        // The balloon that pops is a middle-depth one somewhere in the middle half of the screen.
        let candidates = all.indices.filter { all[$0].depth == .mid && (0.25...0.75).contains(all[$0].x) }
        if let i = candidates.randomElement() ?? all.indices.first(where: { all[$0].depth == .mid }) {
            let b = all[i]
            all[i] = Balloon(depth: b.depth, x: b.x, delay: b.delay, speed: b.speed, sway: b.sway, swaySpeed: b.swaySpeed,
                             phase: b.phase, radius: b.radius, color: b.color, pops: true)
        }
        return all
    }

    private static func duration(height: CGFloat) -> Double {
        maxDelay + Double((height + 300) / slowest)
    }

    let scene: CelebrationScene
    let part: CelebrationPart
    private var balloons: [Balloon] { scene.balloons }
    @State private var finished = false

    /// Where a balloon is at time `t` (seconds since the start), before anything pushes it.
    private func position(_ b: Balloon, _ t: Double, _ size: CGSize) -> CGPoint? {
        let lt = t - b.delay
        guard lt > 0 else { return nil }
        let x = b.x * size.width + b.sway * CGFloat(sin(lt * b.swaySpeed + b.phase))
        let y = size.height + b.radius * 3.4 - b.speed * CGFloat(lt)
        return CGPoint(x: x, y: y)
    }

    private func popTime(_ b: Balloon, height: CGFloat) -> Double {
        b.delay + Double((height * (1 - scene.pop.height) + b.radius * 3.4) / b.speed)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(part.depths, id: \.self) { depth in
                    DepthCanvas(depth: depth, start: scene.start, paused: finished) { layer, t, size in
                        draw(&layer, depth: depth, t: t, size: size)
                    }
                }
            }
            .task(id: geo.size.height) {
                guard let popper = balloons.first(where: \.pops), geo.size.height > 0 else { return }
                let height = geo.size.height
                // Warm the haptic up now so it can't hitch the animation when it fires at the pop.
                let haptics = part == .front && !scene.silent ? Haptics() : nil
                try? await Task.sleep(for: .seconds(CelebrationScene.startDelay + popTime(popper, height: height)))
                haptics?.tap()
                try? await Task.sleep(for: .seconds(max(0, Self.duration(height: height) - popTime(popper, height: height))))
                finished = true
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Draws one depth's balloons (and, with the sharp middle layer, the burst) at time `t`.
    private func draw(_ layer: inout GraphicsContext, depth: Depth, t: Double, size: CGSize) {
        // The pop: when and where, and which balloons it shoves.
        let popper = balloons.first(where: \.pops)
        let tp = popper.map { popTime($0, height: size.height) }
        let popPoint = popper.flatMap { position($0, tp ?? 0, size) }

        for b in balloons where b.depth == depth {
            guard var p = position(b, t, size) else { continue }
            var tilt = 0.12 * sin((t - b.delay) * b.swaySpeed + b.phase)

            if b.pops, let tp, t >= tp { continue }   // gone
            if !b.pops, let tp, t > tp, let popPoint, let at = position(b, tp, size) {
                // Knocked away from the pop, then a damped wobble settles it at its new spot.
                let dx = at.x - popPoint.x, dy = at.y - popPoint.y
                let d = max(1, hypot(dx, dy))
                if d < Self.pushRadius {
                    let dt = t - tp
                    // Each neighbor gets its own shove: a little off-axis, harder or softer, wobbling at its own pace.
                    let skew = sin(b.phase * 7) * 0.4
                    let ux = (dx * cos(skew) - dy * sin(skew)) / d, uy = (dx * sin(skew) + dy * cos(skew)) / d
                    let amount = (1 - d / Self.pushRadius) * scene.pop.pushStrength * b.depth.scale * CGFloat(0.8 + 0.4 * abs(sin(b.phase * 3)))
                    let rate = 10 + 3 * sin(b.phase * 5)
                    let wobble = 1 - exp(-4 * dt) * cos(rate * dt)
                    p.x += ux * amount * CGFloat(wobble)
                    p.y += uy * amount * CGFloat(wobble)
                    tilt += Double(ux) * Double(amount) * 0.004 * exp(-3 * dt) * sin(rate * dt)
                }
            }
            guard p.y > -b.radius * 4 else { continue }     // floated off the top
            // The popper swells and shivers for a beat before it goes.
            var swell: CGFloat = 1
            if b.pops, let tp, t > tp - 0.12 {
                let k = (t - (tp - 0.12)) / 0.12
                swell = 1 + 0.16 * CGFloat(k * k)
                tilt += 0.06 * sin(t * 90) * k
            }
            drawBalloon(layer, b, at: p, tilt: tilt, scale: swell, t: t)
        }

        // The burst is drawn with the sharp middle layer.
        if depth == .mid, let tp, let popper, let popPoint, t >= tp, t - tp < 1.0 {
            drawPop(layer, popper, at: popPoint, dt: t - tp)
        }
    }

    private func drawBalloon(_ ctx: GraphicsContext, _ b: Balloon, at p: CGPoint, tilt: Double, scale: CGFloat = 1, t: Double) {
        let r = b.radius
        var c = ctx
        c.translateBy(x: p.x, y: p.y)
        c.rotate(by: .radians(tilt))
        if scale != 1 { c.scaleBy(x: scale, y: scale) }

        // String, trailing a little behind the sway.
        let wiggle = CGFloat(sin(t * 3 + b.phase)) * r * 0.35
        var string = Path()
        string.move(to: CGPoint(x: 0, y: r * 1.3))
        string.addCurve(to: CGPoint(x: wiggle * 0.5, y: r * 3.3),
                        control1: CGPoint(x: wiggle, y: r * 1.9), control2: CGPoint(x: -wiggle, y: r * 2.6))
        c.stroke(string, with: .color(.gray.opacity(0.55)), lineWidth: max(0.8, r * 0.04))

        // Knot.
        var knot = Path()
        knot.move(to: CGPoint(x: 0, y: r * 1.12))
        knot.addLine(to: CGPoint(x: -r * 0.13, y: r * 1.32))
        knot.addLine(to: CGPoint(x: r * 0.13, y: r * 1.32))
        knot.closeSubpath()
        c.fill(knot, with: .color(b.color))

        // Body, with a soft highlight up and to the left.
        let body = Path(ellipseIn: CGRect(x: -r, y: -r * 1.15, width: r * 2, height: r * 2.3))
        let shading = GraphicsContext.Shading.radialGradient(
            Gradient(stops: [.init(color: .white.opacity(0.8), location: 0),
                             .init(color: b.color, location: 0.38),
                             .init(color: b.color.opacity(0.82), location: 1)]),
            center: CGPoint(x: -r * 0.35, y: -r * 0.5), startRadius: 0, endRadius: r * 1.7)
        c.fill(body, with: shading)
    }

    /// A ragged flash snaps out from the burst and uneven shreds of the balloon fly away and fall.
    private func drawPop(_ ctx: GraphicsContext, _ b: Balloon, at p: CGPoint, dt: Double) {
        let pop = scene.pop
        var c = ctx

        let flash = min(1, dt / 0.2)
        if flash < 1 {
            let reach = b.radius * (0.9 + pop.flashReach * flash)
            var outline = Path()
            for (i, jitter) in pop.flashShape.enumerated() {
                let a = Double(i) / Double(pop.flashShape.count) * 2 * .pi
                let pt = CGPoint(x: p.x + CGFloat(cos(a)) * reach * jitter, y: p.y + CGFloat(sin(a)) * reach * jitter)
                if i == 0 { outline.move(to: pt) } else { outline.addLine(to: pt) }
            }
            outline.closeSubpath()
            c.stroke(outline, with: .color(.white.opacity(0.85 * (1 - flash))),
                     style: StrokeStyle(lineWidth: 3 * (1 - flash) + 0.5, lineJoin: .round))
        }

        for s in pop.shards {
            let fade = max(0, 1 - dt / s.life)
            guard fade > 0 else { continue }
            let settle = (1 - exp(-6 * dt)) / 6
            let x = p.x + CGFloat(cos(s.angle) * s.speed * settle)
            let y = p.y + CGFloat(sin(s.angle) * s.speed * settle + s.gravity * dt * dt / 2)
            var sc = c
            sc.opacity = fade
            sc.translateBy(x: x, y: y)
            sc.rotate(by: .radians(s.angle + dt * s.spin))
            let w = b.radius * s.size.width, h = b.radius * s.size.height
            let path: Path = switch s.kind {
            case .strip, .chunk: Path(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), cornerRadius: min(w, h) * 0.35)
            case .curl: Path { $0.move(to: CGPoint(x: -w / 2, y: 0)); $0.addQuadCurve(to: CGPoint(x: w / 2, y: 0), control: CGPoint(x: 0, y: -h)); $0.addQuadCurve(to: CGPoint(x: -w / 2, y: 0), control: CGPoint(x: 0, y: -h * 0.3)) }
            }
            sc.fill(path, with: .color(b.color))
        }
    }
}
