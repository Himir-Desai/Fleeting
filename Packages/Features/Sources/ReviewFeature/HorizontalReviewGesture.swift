#if os(iOS)
    import SwiftUI
    import UIKit

    /// Recognizes card shortcuts while rejecting vertical drags before they can block scrolling.
    struct HorizontalReviewGesture: UIGestureRecognizerRepresentable {
        let onChange: (CGFloat) -> Void
        let onEnd: (CGFloat, CGFloat) -> Void
        let onCancel: () -> Void

        func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
            let pan = UIPanGestureRecognizer()
            pan.maximumNumberOfTouches = 1
            pan.delegate = context.coordinator
            return pan
        }

        func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
            Coordinator()
        }

        func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
            let distance = pan.translation(in: pan.view).x
            switch pan.state {
            case .began, .changed:
                onChange(distance)
            case .ended:
                let velocity = pan.velocity(in: pan.view).x
                onEnd(distance, distance + (velocity / 1000) * 0.99 / (1 - 0.99))
            case .cancelled, .failed:
                onCancel()
            default:
                break
            }
        }

        final class Coordinator: NSObject, UIGestureRecognizerDelegate {
            func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
                guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
                let velocity = pan.velocity(in: pan.view)
                return abs(velocity.x) > abs(velocity.y)
            }

            func gestureRecognizer(
                _ recognizer: UIGestureRecognizer,
                shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
            ) -> Bool {
                true
            }
        }
    }
#endif
