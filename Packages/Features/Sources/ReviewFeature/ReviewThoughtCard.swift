import DesignSystem
import SwiftUI

/// A scrolling review card with horizontal shortcuts and explicit decisions.
struct ReviewThoughtCard<Content: View>: View {
    let onArchive: () -> Void
    let onKeepActive: () -> Void
    let content: Content
    let canArchive: Bool
    @State private var offset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        onArchive: @escaping () -> Void,
        onKeepActive: @escaping () -> Void,
        canArchive: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.onArchive = onArchive
        self.onKeepActive = onKeepActive
        self.canArchive = canArchive
        self.content = content()
    }

    var body: some View {
        Card { content }
            .offset(x: offset)
        #if os(iOS)
            .gesture(HorizontalReviewGesture(
                onChange: { distance in
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { offset = distance }
                },
                onEnd: { distance, projected in
                    reset()
                    guard abs(distance) >= 24, abs(projected) > 96 else { return }
                    if projected > 0 {
                        onKeepActive()
                    } else if canArchive {
                        onArchive()
                    }
                },
                onCancel: reset
            ))
        #endif
    }

    private func reset() {
        withAnimation(reduceMotion ? nil : Motion.card) { offset = 0 }
    }
}
