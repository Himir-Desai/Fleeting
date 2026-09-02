import SwiftUI

/// What a screen says when it has nothing to show.
///
/// Every empty state in the app is a success rather than a void, so they are written as a
/// sentence the app says — hence ``Typography/display`` — with the explanation beneath.
public struct EmptyState: View {
    private let symbol: String?
    private let title: String
    private let message: String

    /// Creates the empty state.
    /// - Parameters:
    ///   - symbol: An SF Symbol name drawn above the title.
    ///   - title: One short line saying what is true.
    ///   - message: What follows from it, or what to do about it.
    public init(symbol: String, title: String, message: String) {
        self.symbol = symbol
        self.title = title
        self.message = message
    }

    /// Creates an empty state marked with a sprout rather than a symbol.
    ///
    /// For the states that are a success — a list you have cleared, a review with nothing left to
    /// decide. A line-drawn seedling says "this is a good place to be" where a glyph only labels
    /// the absence (ADR-0042).
    /// - Parameters:
    ///   - title: One short line saying what is true.
    ///   - message: What follows from it, or what to do about it.
    public init(title: String, message: String) {
        symbol = nil
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: Spacing.regular) {
            if let symbol {
                Image(systemName: symbol)
                    .font(Typography.symbol)
                    .foregroundStyle(Palette.accentText)
                    .accessibilityHidden(true)
            } else {
                GrowingSprout(size: 52)
            }

            VStack(spacing: Spacing.snug) {
                Text(title)
                    .font(Typography.display)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.loose)
        .accessibilityElement(children: .combine)
    }
}
