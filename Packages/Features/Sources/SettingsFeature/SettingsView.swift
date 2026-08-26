import Core
import DesignSystem
import SwiftUI

/// Shows how the app is behaving: what is sorting thoughts, and how fast each kind decays.
public struct SettingsView: View {
    @State private var model: SettingsModel

    /// Creates the settings screen.
    /// - Parameter model: State for the screen, built by the composition root.
    public init(model: SettingsModel) {
        _model = State(initialValue: model)
    }

    /// The three switches ADR-0009 permits, and nothing more.
    @ViewBuilder
    private var nudgeToggles: some View {
        Toggle("Daily nudge", isOn: binding(\.dailyEnabled))
            .accessibilityIdentifier("settings.nudge.daily")

        if model.preferences.dailyEnabled {
            Picker("Time", selection: binding(\.dailyHour)) {
                ForEach(0 ..< 24, id: \.self) { hour in
                    Text(Self.hourLabel(hour)).tag(hour)
                }
            }
            .accessibilityIdentifier("settings.nudge.dailyHour")
        }

        Toggle("Weekly review invitation", isOn: binding(\.weeklyEnabled))
            .accessibilityIdentifier("settings.nudge.weekly")

        Toggle("Warn before archiving", isOn: binding(\.expiryWarningsEnabled))
            .accessibilityIdentifier("settings.nudge.expiry")
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

    public var body: some View {
        List {
            Section("Sorting") {
                VStack(alignment: .leading, spacing: Spacing.tight) {
                    Text(model.status.headline)
                        .font(Typography.title)
                        .foregroundStyle(Palette.ink)
                    Text(model.status.detail)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
                .padding(.vertical, Spacing.tight)
                .listRowBackground(Palette.raised)
                .accessibilityIdentifier("settings.intelligence")
            }

            Section("Notifications") {
                VStack(alignment: .leading, spacing: Spacing.tight) {
                    Text(model.notificationStatus.headline)
                        .font(Typography.title)
                        .foregroundStyle(Palette.ink)
                    Text(model.notificationStatus.detail)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
                .padding(.vertical, Spacing.tight)
                .listRowBackground(Palette.raised)
                .accessibilityIdentifier("settings.notifications")

                if model.authorization == .notAsked {
                    Button("Turn on notifications") {
                        Task { await model.requestPermission() }
                    }
                    .font(Typography.body)
                    .tint(Palette.accent)
                    .listRowBackground(Palette.raised)
                    .accessibilityIdentifier("settings.notifications.enable")
                }

                if model.canConfigureNudges {
                    nudgeToggles
                }
            }

            Section("Widgets") {
                VStack(alignment: .leading, spacing: Spacing.tight) {
                    Text(model.widgetStatus.headline)
                        .font(Typography.title)
                        .foregroundStyle(model.storageIsShared ? Palette.ink : Palette.fading)
                    Text(model.widgetStatus.detail)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
                .padding(.vertical, Spacing.tight)
                .listRowBackground(Palette.raised)
                .accessibilityIdentifier("settings.widgets")
            }

            Section("How long things last") {
                ForEach(model.lifetimes, id: \.kind) { entry in
                    HStack {
                        Text(entry.kind.rawValue.capitalized)
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(entry.days) days")
                            .foregroundStyle(Palette.inkMuted)
                    }
                    .font(Typography.body)
                    .listRowBackground(Palette.raised)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.surface)
        .navigationTitle("Settings")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await model.load() }
    }
}
