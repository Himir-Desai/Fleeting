import Core
import DesignSystem
import SwiftUI

/// The number and unit wheels that set how long a thought lasts.
///
/// Duplicated from capture rather than shared: a view that names an ``ExpirationUnit`` is
/// domain-shaped, so it cannot live in `DesignSystem`, and features do not import each other
/// (ADR-0012). The duplication is small and visible, which is the point.
struct ExpiryWheels: View {
    /// The amount of ``unit`` the thought lasts.
    @Binding var count: Int
    /// The unit the ``count`` is measured in.
    @Binding var unit: ExpirationUnit

    var body: some View {
        HStack(spacing: 0) {
            Picker("Amount", selection: $count) {
                ForEach(1 ... 60, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .wheel()
            .accessibilityIdentifier("detail.expiration.count")

            Picker("Unit", selection: $unit) {
                ForEach(ExpirationUnit.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            .wheel()
            .accessibilityIdentifier("detail.expiration.unit")
        }
        .frame(height: 120)
        .tint(Palette.accentText)
    }
}

private extension View {
    /// Applies the wheel picker style on iOS, and leaves the default elsewhere.
    @ViewBuilder
    func wheel() -> some View {
        #if os(iOS)
            pickerStyle(.wheel)
        #else
            self
        #endif
    }
}
