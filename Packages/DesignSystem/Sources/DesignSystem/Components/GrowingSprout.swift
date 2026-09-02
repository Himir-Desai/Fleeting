import SwiftUI

/// A ``SproutMark`` that grows itself once, when it appears.
///
/// The form the mark takes at every call site, so no feature has to own an animation phase or
/// remember that Reduce Motion means "already grown" rather than "no mark" (ADR-0042).
public struct GrowingSprout: View {
    private let size: CGFloat
    private let tint: Color

    @State private var progress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates a mark that grows on appearance.
    /// - Parameters:
    ///   - size: The square the mark is drawn in.
    ///   - tint: The stroke colour.
    public init(size: CGFloat = 28, tint: Color = Palette.accentText) {
        self.size = size
        self.tint = tint
    }

    public var body: some View {
        SproutMark(progress: progress, tint: tint)
            .frame(width: size, height: size)
            .onAppear {
                guard !reduceMotion else {
                    // Fully grown, immediately. The mark is decoration, so the answer to "no
                    // motion" is the end state rather than nothing at all.
                    progress = 1
                    return
                }
                withAnimation(Motion.growth) { progress = 1 }
            }
    }
}
