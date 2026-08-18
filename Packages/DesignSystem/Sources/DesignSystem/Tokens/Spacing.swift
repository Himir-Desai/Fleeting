import CoreGraphics

/// Layout spacing steps. Features never use raw numeric padding.
public enum Spacing {
    /// 2pt — hairline separation.
    public static let hairline: CGFloat = 2
    /// 4pt — within a single line of content.
    public static let tight: CGFloat = 4
    /// 8pt — between closely related elements.
    public static let snug: CGFloat = 8
    /// 12pt — the default gap.
    public static let regular: CGFloat = 12
    /// 20pt — between distinct groups.
    public static let loose: CGFloat = 20
    /// 32pt — between sections of a screen.
    public static let section: CGFloat = 32
}
