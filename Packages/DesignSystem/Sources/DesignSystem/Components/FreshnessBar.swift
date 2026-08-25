import SwiftUI

/// A thin meter showing how much freshness a thought has left.
public struct FreshnessBar: View {
    private let freshness: Double

    /// Creates the meter.
    /// - Parameter freshness: A value within 0...1.
    public init(freshness: Double) {
        self.freshness = min(max(freshness, 0), 1)
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.ink.opacity(0.10))
                Capsule()
                    .fill(FreshnessStyle.tint(for: freshness))
                    .frame(width: max(proxy.size.width * freshness, 2))
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}
