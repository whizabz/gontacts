import CoreMotion
import SwiftUI

/// Reads how the phone is tilted and shares it with every view that wants a parallax effect.
///
/// It tracks the change from where the phone was when you started looking at the screen, and slowly re-centres, so
/// holding the phone at any comfortable angle works and the effect comes from moving it. Nothing is read when
/// Reduce Motion is on, and no permission is needed.
@MainActor @Observable
final class MotionTilt {
    static let shared = MotionTilt()

    /// Tilt left/right and forward/back, each from -1 to 1.
    private(set) var x: CGFloat = 0
    private(set) var y: CGFloat = 0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var users = 0
    @ObservationIgnored private var baseline: (x: Double, y: Double)?

    func start() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let g = motion?.gravity else { return }
            MainActor.assumeIsolated { self.update(gx: g.x, gy: g.y) }
        }
    }

    func stop() {
        users = max(0, users - 1)
        guard users == 0 else { return }
        manager.stopDeviceMotionUpdates()
        baseline = nil
        x = 0
        y = 0
    }

    private func update(gx: Double, gy: Double) {
        var base = baseline ?? (gx, gy)
        // The resting position drifts toward where the phone is held, so the cards settle back to the middle.
        base = (base.x + (gx - base.x) * 0.015, base.y + (gy - base.y) * 0.015)
        baseline = base
        let targetX = max(-1, min(1, (gx - base.x) * 3.2))
        let targetY = max(-1, min(1, (gy - base.y) * 3.2))
        x += (targetX - x) * 0.3
        y += (targetY - y) * 0.3
    }
}

/// Moves and slightly turns a view as the phone is tilted, so it seems to float above the screen.
private struct TiltParallax: ViewModifier {
    var travel: CGFloat
    var turn: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let motion = MotionTilt.shared

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(Double(motion.x) * turn), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(-Double(motion.y) * turn), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .offset(x: -motion.x * travel, y: -motion.y * travel)
            .onAppear { if !reduceMotion { motion.start() } }
            .onDisappear { if !reduceMotion { motion.stop() } }
    }
}

extension View {
    /// `travel` is how far the view moves at full tilt, in points; `turn` is how many degrees it turns.
    func tiltParallax(travel: CGFloat, turn: Double = 6) -> some View {
        modifier(TiltParallax(travel: travel, turn: turn))
    }
}
