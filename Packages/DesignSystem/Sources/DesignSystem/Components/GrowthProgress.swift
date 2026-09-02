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
                // The vine is always drawn at full width with one leaf per card in the session,
                // and a mask reveals as much of it as has been decided. Sizing the vine itself to
                // the fraction made the whole drawing scale — the leaves slid apart as the bar
                // advanced, which read as the line stretching rather than a plant growing.
                Vine(leaves: total)
                    .stroke(
                        Palette.accentText.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round)
                    )
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: proxy.size.width * fraction)
                    }
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
