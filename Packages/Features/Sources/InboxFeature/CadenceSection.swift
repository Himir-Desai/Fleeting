import Core
import DesignSystem
import SwiftUI

/// How often a habit is meant to be kept, and the way to change it.
///
/// The app reads a cadence out of the note's own wording — "read every week" is weekly — but the
/// wording is often silent or wrong, and a habit asked for on the wrong rhythm stops being a
/// habit. This is where that guess is corrected, on the thought's own page, which is where a
/// decision about a thought belongs (ADR-0048).
struct CadenceSection: View {
    /// The cadence currently in force.
    let cadence: HabitCadence

    /// Whether the app guessed this rather than the user choosing it, so the screen can say so.
    let isInferred: Bool

    /// Chooses a new cadence.
    let onChoose: (HabitCadence) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            SectionLabel("How often")

            Picker("How often", selection: selection) {
                ForEach(HabitCadence.allCases, id: \.self) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(Palette.accentText)
            .accessibilityIdentifier("detail.cadence")
            .accessibilityLabel("How often: \(cadence.label)")

            if isInferred {
                Text("Picked from your own words. Change it if that is not the rhythm you meant.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The picker's binding, which reports a choice rather than owning the value.
    private var selection: Binding<HabitCadence> {
        Binding(get: { cadence }, set: onChoose)
    }
}
