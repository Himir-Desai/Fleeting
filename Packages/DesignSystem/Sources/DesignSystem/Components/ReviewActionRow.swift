import SwiftUI

/// Keeps one set of review controls, stacking long or large-text decisions.
public struct ReviewActionRow<Content: View>: View {
    private let content: Content
    private let stacked: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(stacked: Bool = false, @ViewBuilder content: () -> Content) {
        self.stacked = stacked
        self.content = content()
    }

    public var body: some View {
        let layout = stacked || typeSize > .large
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.snug))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.snug))
        layout { content.fixedSize(horizontal: false, vertical: true) }
    }
}
