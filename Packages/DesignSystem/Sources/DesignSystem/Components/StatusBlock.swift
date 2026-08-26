import SwiftUI

/// An answer and its explanation: what the app is doing, then why in smaller type.
///
/// The shape every honest-status line in Settings takes, so a new one is a call rather than
/// another hand-built stack.
public struct StatusBlock: View {
    /// Whether the state being described is the expected one.
    public enum Tone: Sendable {
        /// Working as intended.
        case normal
        /// Degraded, or off. Drawn in the warning colour.
        case warning
    }

    private let headline: String
    private let detail: String
    private let tone: Tone

    /// Creates the block.
    /// - Parameters:
    ///   - headline: The answer, in one short sentence.
    ///   - detail: Why, or what follows from it.
    ///   - tone: Whether this is the expected state. Defaults to ``Tone/normal``.
    public init(headline: String, detail: String, tone: Tone = .normal) {
        self.headline = headline
        self.detail = detail
        self.tone = tone
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            Text(headline)
                .font(Typography.subtitle)
                .foregroundStyle(tone == .warning ? Palette.fading : Palette.ink)
            Text(detail)
                .font(Typography.caption)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
