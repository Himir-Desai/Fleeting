import DesignSystem
import SwiftUI

/// A switch with a name and a line saying what turning it on actually does.
///
/// The stock `Toggle` in a `Form` row was the one piece of Settings that still looked like the
/// system's settings rather than this app's (ADR-0032). This keeps the platform switch, because
/// a switch is a switch, but sets it in the app's own type and spacing.
struct SettingsToggle: View {
    /// The switch's name.
    let label: String
    /// What turning it on does, in one short line.
    let detail: String
    /// Whether it is on.
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: Spacing.hairline) {
                Text(label)
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Palette.accent)
    }
}
