import SwiftUI

/// A section's name, set small and wide above the content it introduces.
public struct SectionLabel: View {
    private let text: String

    /// Creates the label.
    /// - Parameter text: The section's name, written in sentence case.
    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text.uppercased())
            .font(Typography.label)
            .tracking(Typography.labelTracking)
            .foregroundStyle(Palette.inkMuted)
            .accessibilityLabel(text)
    }
}
