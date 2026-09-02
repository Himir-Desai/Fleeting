import SwiftUI

/// A vine that grows along a line as a session advances.
///
/// Ambient rather than triggered: it is on screen before the user does anything, and each decision
/// extends it. The point of the botanical language is that the app is a place where things grow,
/// and a mark that only ever appears as a reward for pressing something is a sticker (ADR-0045).
///
/// Replaces the review's plain `ProgressView`, which said the same number in a duller way.
public struct GrowthProgress: View {
    private let position: Int
    private let total: Int

    /// Creates the progress vine.
    /// - Parameters:
    ///   - position: How many cards have been decided.
    ///   - total: How many there are in the session.
    public init(position: Int, total: Int) {
        self.position = max(position, 0)
        self.total = max(total, 1)
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            // The path not yet walked, drawn as a bare line so the grown part reads as growth
            // against something rather than as a bar filling up.
            Capsule()
                .fill(FreshnessStyle.track)
                .frame(height: 1)

            GeometryReader { proxy in
                VineRule(leaves: max(position, 1), tint: Palette.accentText, drawn: true)
                    .frame(width: max(proxy.size.width * fraction, 1))
                    .opacity(position == 0 ? 0 : 1)
            }
        }
        .frame(height: 18)
        .motion(Motion.growth, value: position)
        .accessibilityHidden(true)
    }

    /// How far along the session is.
    private var fraction: Double {
        min(Double(position) / Double(total), 1)
    }
}
