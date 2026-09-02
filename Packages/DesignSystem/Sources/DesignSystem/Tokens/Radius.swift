import CoreGraphics

/// Corner radii. Features never use raw numeric radii, so the app's roundness is one decision
/// rather than a dozen.
public enum Radius {
    /// 10pt — buttons, chips, and anything the user taps.
    public static let control: CGFloat = 10
    /// 16pt — a thought row, a review card.
    public static let card: CGFloat = 16
    /// 22pt — a full-width well the user types into.
    ///
    /// Capture stopped drawing one when it became a full-bleed page (ADR-0039), so the thought
    /// detail's editable text is the only well left.
    public static let well: CGFloat = 22
}
