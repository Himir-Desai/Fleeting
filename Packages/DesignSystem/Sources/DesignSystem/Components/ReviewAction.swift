import SwiftUI

/// A labelled review decision shared by thought and daily-task cards.
public struct ReviewAction: View {
    private let title: String
    private let symbol: String
    private let tint: Color
    private let action: () -> Void

    public init(_ title: String, symbol: String, tint: Color, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(title, systemImage: symbol, action: action)
            .font(Typography.body)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(tint)
    }
}
