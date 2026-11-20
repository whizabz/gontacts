import SwiftUI
import UIKit

/// Which animation plays when you open a contact with an event today.
enum CelebrationStyle: String, CaseIterable, Identifiable {
    case confetti, balloons

    var id: String { rawValue }
    var title: String { self == .confetti ? "Confetti" : "Balloons" }
}

/// How far from the "camera" a piece is. Far pieces are small, slow and a little soft, middle ones are sharp,
/// and near ones are big, fast and heavily blurred, like the out-of-focus foreground in a photo.
/// The two farthest layers are drawn behind the page's content, the other two in front of it.
/// Each layer is blurred once as a group, which is far cheaper than blurring every piece.
enum Depth: Int, CaseIterable {
    case far, back, mid, near

    var scale: CGFloat { [0.6, 0.85, 1.05, 1.7][rawValue] }
    var blur: CGFloat { [1.8, 0.8, 0, 6][rawValue] }
    var opacity: Double { [0.8, 0.9, 1, 0.92][rawValue] }
    /// Parallax: nearer things cross the screen faster.
    var speed: CGFloat { [0.75, 0.9, 1, 1.3][rawValue] }

    static func random() -> Depth {
        switch Int.random(in: 0..<100) {
        case ..<20: .far
        case ..<45: .back
        case ..<80: .mid
        default: .near
        }
    }
}

/// Which side of the page's content a celebration layer is drawn on.
enum CelebrationPart {
    case back, front

    var depths: [Depth] { self == .back ? [.far, .back] : [.mid, .near] }
}

/// One run of a celebration: the pieces, rolled once, and when it started. Both the layer behind the content
/// and the layer in front of it read the same scene, so they stay in step. Make a new scene to replay.
final class CelebrationScene {
    static let startDelay = 0.1     // a beat to warm up the haptics before firing
    let start: Date
    /// A warm-up scene plays invisibly with no haptics, only to get the drawing pipelines ready.
    let silent: Bool
    /// Confetti pieces by depth, and the balloons (which are drawn per depth but interact across depths).
    let confetti: [[ConfettiView.Piece]]
    let balloons: [BalloonsView.Balloon]
    /// This run's balloon burst, rolled once so it differs every time.
    let pop = BalloonsView.Pop()

    init(warmup: Bool = false) {
        silent = warmup
        // A warm-up starts partway in, so pieces are already in flight on its first frame.
        start = Date().addingTimeInterval(warmup ? -1.0 : CelebrationScene.startDelay)
        let pieces = ConfettiView.makePieces()
        confetti = Depth.allCases.map { d in pieces.filter { $0.depth == d } }
        balloons = BalloonsView.makeBalloons()
    }
}

/// One side of the animation for a style. Callers decide whether to show it at all (setting, Reduce Motion).
struct CelebrationView: View {
    let style: CelebrationStyle
    let scene: CelebrationScene
    let part: CelebrationPart

    var body: some View {
        switch style {
        case .confetti: ConfettiView(scene: scene, part: part)
        case .balloons: BalloonsView(scene: scene, part: part)
        }
    }
}

/// One depth layer of a celebration, drawn on its own canvas.
///
/// Performance: the blurred layers are drawn at half size and scaled back up, so the blur works on a quarter
/// of the pixels (the blur hides the lost detail), and drawing is capped at 60 fps even on a 120 Hz display.
struct DepthCanvas: View {
    let depth: Depth
    let start: Date
    let paused: Bool
    /// Draws this depth's pieces at time `t`, in a canvas of the given (full-size) dimensions.
    let draw: (inout GraphicsContext, Double, CGSize) -> Void

    var body: some View {
        let k: CGFloat = depth.blur > 0 ? 0.5 : 1
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: paused)) { timeline in
                Canvas(rendersAsynchronously: true) { context, size in
                    let t = timeline.date.timeIntervalSince(start)
                    guard t > 0 else { return }
                    context.scaleBy(x: k, y: k)
                    context.drawLayer { layer in
                        if depth.blur > 0 { layer.addFilter(.blur(radius: depth.blur * k)) }
                        layer.opacity = depth.opacity
                        draw(&layer, t, CGSize(width: size.width / k, height: size.height / k))
                    }
                }
            }
            .frame(width: geo.size.width * k, height: geo.size.height * k)
            .scaleEffect(1 / k, anchor: .topLeading)
        }
    }
}

/// Haptic generators are warmed up with `prepare()` ahead of time. Creating one at the moment it fires can
/// stall the main thread while the Taptic Engine spins up, which shows as a hitch in the animation.
@MainActor
struct Haptics {
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let light = UIImpactFeedbackGenerator(style: .light)

    init() { prepare() }

    func prepare() { medium.prepare(); light.prepare() }
    func thump() { medium.impactOccurred() }
    func tap(_ intensity: CGFloat = 1) { light.impactOccurred(intensity: intensity) }
}

/// Plays the chosen celebration once, nearly invisible, as soon as the app knows someone has an event today.
/// The first time the blurred layers and canvases draw is the slowest; doing it here means the real run, when you
/// open the contact, is not the first.
struct CelebrationWarmup: View {
    let style: CelebrationStyle
    @State private var scene = CelebrationScene(warmup: true)
    @State private var done = false

    var body: some View {
        if !done {
            ZStack {
                CelebrationView(style: style, scene: scene, part: .back)
                CelebrationView(style: style, scene: scene, part: .front)
            }
            .frame(width: 240, height: 480)
            .opacity(0.02)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                try? await Task.sleep(for: .seconds(0.8))
                done = true
            }
        }
    }
}
