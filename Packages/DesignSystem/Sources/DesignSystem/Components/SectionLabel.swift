import SwiftUI

/// A section's name, set small and wide above the content it introduces.
public struct SectionLabel: View {
    private let text: String
    private let tint: Color
    private let weight: Font.Weight?

    /// Creates the label.
    /// - Parameter text: The section's name, written in sentence case.
    public init(_ text: String) {
        self.text = text
        tint = Palette.inkMuted
        weight = nil
    }

    /// Creates a label that carries its own emphasis.
    ///
    /// For the one heading in a run that means something the others do not — a list's most urgent
    /// group, say. Three identically grey headings say the sections differ without saying that one
    /// of them matters (ADR-0041).
    /// - Parameters:
    ///   - text: The section's name, written in sentence case.
    ///   - tint: The colour to set it in.
    ///   - weight: A heavier weight, or `nil` to keep the scale's own.
    public init(_ text: String, tint: Color, weight: Font.Weight? = nil) {
        self.text = text
        self.tint = tint
        self.weight = weight
    }

    public var body: some View {
        Text(text.uppercased())
            .font(Typography.label)
            .fontWeight(weight)
            .tracking(Typography.labelTracking)
            .foregroundStyle(tint)
            .accessibilityLabel(text)
    }
}
