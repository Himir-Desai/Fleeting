import Core
import DesignSystem
import SwiftUI

/// Where the app's behaviour is changed.
///
/// Every section here is a control. The things that cannot be changed — where thoughts are
/// stored, whether iCloud is reachable, whether the widgets can see the store — are facts about
/// the device rather than preferences, so they sit together under About instead of impersonating
/// settings (ADR-0032).
public struct SettingsView: View {
    @State private var model: SettingsModel

    /// Creates the settings screen.
    /// - Parameter model: State for the screen, built by the composition root.
    public init(model: SettingsModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                sorting
                notifications
                lifetimes
                about
            }
            .padding(.horizontal, Spacing.loose)
            .padding(.vertical, Spacing.loose)
        }
        .background(Palette.surface)
        .navigationTitle("Settings")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await model.load() }
    }

    /// A titled group of controls on one card.
    private func section(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.regular) {
            SectionLabel(title)
            VStack(alignment: .leading, spacing: Spacing.regular) {
                content()
            }
            .padding(Spacing.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Palette.raised)
            }
        }
    }

    /// The sorting choice, and what that choice is actually getting right now.
    private var sorting: some View {
        section("Sorting") {
            HStack(spacing: Spacing.snug) {
                ForEach(SortingPreference.allCases) { choice in
                    ChoiceChip(
                        label: choice.label,
                        isSelected: model.sorting == choice
                    ) {
                        Task { await model.chooseSorting(choice) }
                    }
                    .accessibilityIdentifier("settings.sorting.\(choice.rawValue)")
                }
            }

            Text(model.sorting.explanation)
                .font(Typography.caption)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(Palette.surfaceSunken)

            // What the choice is currently getting, which is not always what was asked for.
            Text(model.sortingReality)
                .font(Typography.caption)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.sorting.reality")
        }
    }

    /// Permission, then the three switches ADR-0009 permits.
    private var notifications: some View {
        section("Notifications") {
            if model.canConfigureNudges {
                SettingsToggle(
                    label: "Daily nudge",
                    detail: "One forgotten thought, brought back.",
                    isOn: binding(\.dailyEnabled)
                )
                .accessibilityIdentifier("settings.nudge.daily")

                if model.preferences.dailyEnabled {
                    SettingsStepperRow(
                        label: "Time",
                        value: Self.hourLabel(model.preferences.dailyHour),
                        onDecrease: { adjustHour(-1) },
                        onIncrease: { adjustHour(1) }
                    )
                    .accessibilityIdentifier("settings.nudge.dailyHour")
                }

                SettingsToggle(
                    label: "Weekly review",
                    detail: "An invitation to decide what to keep.",
                    isOn: binding(\.weeklyEnabled)
                )
                .accessibilityIdentifier("settings.nudge.weekly")

                SettingsToggle(
                    label: "Warn before archiving",
                    detail: "A heads-up before a thought runs out.",
                    isOn: binding(\.expiryWarningsEnabled)
                )
                .accessibilityIdentifier("settings.nudge.expiry")
            } else {
                Text(model.authorization == .denied
                    ? "Notifications are turned off for Fleeting in the Settings app."
                    : "Fleeting can resurface a forgotten thought once a day. It never asks twice.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if model.authorization == .notAsked {
                    Button("Turn on notifications") {
                        Task { await model.requestPermission() }
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .tint(Palette.accent)
                    .accessibilityIdentifier("settings.notifications.enable")
                }
            }
        }
    }

    /// The decay rates, each one editable.
    private var lifetimes: some View {
        section("How long things last") {
            ForEach(model.lifetimes, id: \.kind) { entry in
                SettingsStepperRow(
                    label: KindGlyph.label(for: entry.kind),
                    symbol: KindGlyph.name(for: entry.kind),
                    value: "\(entry.days) \(entry.days == 1 ? "day" : "days")",
                    onDecrease: { model.setLifetime(days: entry.days - 1, for: entry.kind) },
                    onIncrease: { model.setLifetime(days: entry.days + 1, for: entry.kind) }
                )
                .accessibilityIdentifier("settings.lifetime.\(entry.kind.rawValue)")
            }

            Text("A thought archives itself once it runs out of freshness. Nothing is deleted.")
                .font(Typography.caption)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            if model.lifetimesAreCustom {
                Button("Reset to defaults") {
                    model.resetLifetimes()
                }
                .font(Typography.subtitle)
                .foregroundStyle(Palette.accentText)
                .accessibilityIdentifier("settings.lifetimes.reset")
            }
        }
    }

    /// The facts the user cannot change but would be misled by not knowing.
    private var about: some View {
        section("About") {
            if let warning = model.warning {
                Text(warning)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.fading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.warning")
            }

            ForEach(model.facts, id: \.label) { fact in
                HStack {
                    Text(fact.label)
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: Spacing.snug)
                    Text(fact.value)
                        .foregroundStyle(fact.isWarning ? Palette.fading : Palette.inkMuted)
                }
                .font(Typography.body)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.fact.\(fact.label.lowercased())")
            }
        }
    }

    /// Moves the daily nudge an hour, wrapping around the clock.
    private func adjustHour(_ delta: Int) {
        Task {
            await model.update { $0.dailyHour = ($0.dailyHour + delta + 24) % 24 }
        }
    }

    /// A binding that writes a preference change straight through the model.
    /// - Parameter path: Which preference to bind.
    /// - Returns: A binding over that preference.
    private func binding<Value>(
        _ path: WritableKeyPath<NudgePreferences, Value>
    ) -> Binding<Value> {
        Binding(
            get: { model.preferences[keyPath: path] },
            set: { value in Task { await model.update { $0[keyPath: path] = value } } }
        )
    }

    /// A readable label for an hour of the day.
    /// - Parameter hour: Hour, 0–23.
    /// - Returns: A short label such as "7pm".
    private static func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: "12am"
        case 1 ..< 12: "\(hour)am"
        case 12: "12pm"
        default: "\(hour - 12)pm"
        }
    }
}
