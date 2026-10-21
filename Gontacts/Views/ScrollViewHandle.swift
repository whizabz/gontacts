import SwiftUI
import UIKit

/// Finds the UIScrollView behind a SwiftUI List so we can stop its momentum.
/// `ScrollViewProxy.scrollTo` is ignored while a fling is still decelerating, which made buttons that jump
/// to a position feel dead until the scrolling settled.
struct ScrollViewHandle: UIViewRepresentable {
    final class Box {
        weak var scrollView: UIScrollView?

        /// Halts any drag or deceleration in progress, so the next programmatic scroll takes effect.
        func stopMomentum() {
            guard let sv = scrollView, sv.isDecelerating || sv.isDragging else { return }
            sv.setContentOffset(sv.contentOffset, animated: false)
        }

        /// Scrolls to the very top, under the large title.
        func scrollToTop() {
            guard let sv = scrollView else { return }
            sv.setContentOffset(CGPoint(x: 0, y: -sv.adjustedContentInset.top), animated: true)
        }
    }

    let box: Box

    func makeUIView(context: Context) -> UIView {
        let view = Finder(box: box)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private final class Finder: UIView {
        let box: Box
        init(box: Box) {
            self.box = box
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in self?.locate() }
        }

        private func locate() {
            var ancestor: UIView? = superview
            for _ in 0..<8 {
                guard let a = ancestor else { return }
                if let sv = Self.firstScrollView(in: a) {
                    box.scrollView = sv
                    return
                }
                ancestor = a.superview
            }
        }

        private static func firstScrollView(in root: UIView) -> UIScrollView? {
            var queue = [root]
            while !queue.isEmpty {
                let v = queue.removeFirst()
                if let sv = v as? UIScrollView, sv.bounds.height > 200 { return sv }
                queue.append(contentsOf: v.subviews)
            }
            return nil
        }
    }
}
