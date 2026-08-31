import Core
import DesignSystem
import SwiftUI

/// The number and unit wheels that set how long a capture lasts.
///
/// Always visible while advanced options are open. Both wheels spin in place, so the keyboard
/// never drops and the field stays focused; the value defaults to the selected type's period.
struct ExpiryWheels: View {
    /// The amount of ``unit`` the capture lasts.
    @Binding var count: Int
    /// The unit the ``count`` is measured in.
    @Binding var unit: ExpirationUnit

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            SectionLabel("Expires in")

            HStack(spacing: 0) {
                Picker("Amount", selection: $count) {
                    ForEach(1 ... 60, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .wheel()
                .accessibilityIdentifier("advanced.expiration.count")

                Picker("Unit", selection: $unit) {
                    ForEach(ExpirationUnit.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                .wheel()
                .accessibilityIdentifier("advanced.expiration.unit")
            }
            .frame(height: 120)
            .tint(Palette.accentText)
        }
    }
}

private extension View {
    /// Applies the wheel picker style on iOS, and leaves the default elsewhere.
    ///
    /// The Features package builds on macOS so its tests run without a simulator, and `.wheel`
    /// is iOS-only; the app that renders this view is iOS, where the wheel is what shows.
    @ViewBuilder
    func wheel() -> some View {
        #if os(iOS)
            pickerStyle(.wheel)
        #else
            self
        #endif
    }
}
