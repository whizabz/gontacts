import SwiftUI
import UIKit

/// Shows SwiftUI content with iOS's own parallax: the content drifts a few points as the phone is tilted, the same
/// motion effect the system uses for the home screen wallpaper. iOS turns it off by itself when Reduce Motion is on.
///
/// SwiftUI has no motion-effect modifier, so the content is hosted in a UIKit view that carries the effect.
struct ParallaxHost<Content: View>: UIViewRepresentable {
    /// How far the content moves at full tilt, in points.
    var travel: CGFloat = 8
    @ViewBuilder var content: Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let host = UIHostingController(rootView: content)
        host.sizingOptions = .intrinsicContentSize
        host.view.backgroundColor = .clear
        context.coordinator.host = host

        let x = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        let y = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        for effect in [x, y] {
            effect.minimumRelativeValue = -travel
            effect.maximumRelativeValue = travel
        }
        let group = UIMotionEffectGroup()
        group.motionEffects = [x, y]
        host.view.addMotionEffect(group)
        return host.view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.host?.rootView = content
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        return context.coordinator.host?.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    final class Coordinator {
        var host: UIHostingController<Content>?
    }
}
