import Core
import DesignSystem
import SwiftUI

/// How often a habit is meant to be kept: a number, a unit, and the way to change both.
///
/// The app reads a rhythm out of the note's own wording — "read every week" is weekly — but the
/// wording is often silent or wrong, and a habit asked for on the wrong rhythm stops being a
/// habit. This is where that guess is corrected, on the thought's own page, which is where a
/// decision about a thought belongs (ADR-0048).
///
/// Wheels rather than a menu of named rhythms, so "every 3 days" is sayable without the app
/// having had to anticipate it — and the same two wheels the expiry section uses, because a
/// duration is a duration (ADR-0050).
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

            Text("Every \(cadence.count) \(unitName)")
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .accessibilityIdentifier("detail.cadence")
                .accessibilityLabel("How often: \(cadence.label)")

            CadenceWheels(count: countBinding, unit: unitBinding)

            if isInferred {
                Text("Picked from your own words. Change it if that is not the rhythm you meant.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The unit's name, singular when there is only one of it, so the line reads as English.
    private var unitName: String {
        let plural = cadence.unit.label.lowercased()
        return cadence.count == 1 ? String(plural.dropLast()) : plural
    }

    /// The number wheel's binding, which reports a choice rather than owning the value.
    private var countBinding: Binding<Int> {
        Binding(
            get: { cadence.count },
            set: { onChoose(HabitCadence(count: $0, unit: cadence.unit)) }
        )
    }

    /// The unit wheel's binding.
    private var unitBinding: Binding<ExpirationUnit> {
        Binding(
            get: { cadence.unit },
            set: { onChoose(HabitCadence(count: cadence.count, unit: $0)) }
        )
    }
}

/// The number and unit wheels that set how often a habit comes round.
///
/// Capped at 30 rather than the expiry wheels' 60: a habit kept every 31 months is not a habit,
/// and a shorter wheel is a faster one to spin.
struct CadenceWheels: View {
    /// How many ``unit`` between one keeping and the next.
    @Binding var count: Int

    /// The unit the ``count`` is measured in.
    @Binding var unit: ExpirationUnit

    var body: some View {
        HStack(spacing: 0) {
            Picker("Every", selection: $count) {
                ForEach(1 ... 30, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .cadenceWheel()
            .accessibilityIdentifier("detail.cadence.count")

            Picker("Unit", selection: $unit) {
                ForEach(ExpirationUnit.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            .cadenceWheel()
            .accessibilityIdentifier("detail.cadence.unit")
        }
        .frame(height: 120)
        .tint(Palette.accentText)
    }
}

private extension View {
    /// Applies the wheel picker style on iOS, and leaves the default elsewhere.
    @ViewBuilder
    func cadenceWheel() -> some View {
        #if os(iOS)
            pickerStyle(.wheel)
        #else
            self
        #endif
    }
}
