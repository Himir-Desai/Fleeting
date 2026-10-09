import SwiftUI

public extension View {
    /// Aligns a serif page heading with trailing toolbar controls.
    func pageHeading(_ title: String) -> some View {
        navigationTitle("")
        #if os(iOS)
            .toolbar(.visible, for: .navigationBar)
        #endif
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Text(title)
                            .font(Typography.pageTitle)
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: true, vertical: false)
                            .accessibilityAddTraits(.isHeader)
                    }
                    .sharedBackgroundVisibility(.hidden)
                #else
                    ToolbarItem(placement: .navigation) {
                        Text(title).font(Typography.pageTitle)
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    }
                #endif
            }
    }
}

public extension View {
    /// Lays out a primary page title and its actions in one evenly aligned row.
    func pageHeading(
        _ title: String,
        titleIdentifier: String = "page.heading",
        @ViewBuilder actions: () -> some View
    ) -> some View {
        navigationTitle("")
        #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
        #endif
            .safeAreaInset(edge: .top, spacing: 0) {
                PageHeader(title: title, titleIdentifier: titleIdentifier, actions: actions())
                    .frame(minHeight: 52)
                    .padding(.horizontal, Spacing.loose)
                    .padding(.vertical, Spacing.snug)
                    .background(Palette.surface)
            }
    }
}

/// Keeps one live set of actions while adapting navigation chrome to text size.
private struct PageHeader<Actions: View>: View {
    let title: String
    let titleIdentifier: String
    let actions: Actions
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize > .large
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.regular))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.regular))
        layout {
            Text(title)
                .font(Typography.pageTitle)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .layoutPriority(1)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(titleIdentifier)
            HStack(spacing: Spacing.snug) { actions }
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
