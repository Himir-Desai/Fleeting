import SwiftUI

/// Equal-size toolbar actions with balanced padding inside one glass capsule.
public struct ToolbarPill<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: Spacing.tight) { content }
            .font(Typography.controlSymbol)
            .labelStyle(.iconOnly)
            .buttonStyle(PillActionStyle())
            .padding(.horizontal, Spacing.snug)
            .padding(.vertical, Spacing.tight)
            .floatingGlass()
            .fixedSize()
            .foregroundStyle(Palette.accentText)
            .accessibilityElement(children: .contain)
    }
}

private struct PillActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

public extension View {
    /// Gives a floating control a glass capsule without a full-width background bar.
    func floatingGlass() -> some View {
        modifier(FloatingGlass())
    }
}

private struct FloatingGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content.background(Palette.raised, in: Capsule())
                .overlay { Capsule().strokeBorder(Palette.separator, lineWidth: 1) }
        } else {
            #if os(iOS)
                content.glassEffect(.regular.interactive(), in: .capsule)
            #else
                content.background(.ultraThinMaterial, in: Capsule())
            #endif
        }
    }
}
