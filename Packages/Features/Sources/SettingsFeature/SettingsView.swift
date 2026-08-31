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
            .modifier(SettingsRow())
            .accessibilityIdentifier("settings.nudge.daily")

        if model.preferences.dailyEnabled {
            Picker("Time", selection: binding(\.dailyHour)) {
                ForEach(0 ..< 24, id: \.self) { hour in
                    Text(Self.hourLabel(hour)).tag(hour)
                }
            }
            .modifier(SettingsRow())
            .accessibilityIdentifier("settings.nudge.dailyHour")
        }

        Toggle("Weekly review invitation", isOn: binding(\.weeklyEnabled))
            .modifier(SettingsRow())
            .accessibilityIdentifier("settings.nudge.weekly")

        Toggle("Warn before archiving", isOn: binding(\.expiryWarningsEnabled))
            .modifier(SettingsRow())
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
            Section {
                StatusBlock(headline: model.status.headline, detail: model.status.detail)
                    .modifier(SettingsRow())
                    .accessibilityIdentifier("settings.intelligence")
            } header: {
                SectionLabel("Sorting")
            }

            Section {
                VStack(alignment: .leading, spacing: Spacing.regular) {
                    StatusBlock(
                        headline: model.notificationStatus.headline,
                        detail: model.notificationStatus.detail
                    )
                    .accessibilityIdentifier("settings.notifications")

                    // The one action on this screen, so it sits inside the card it acts on
                    // rather than below as a seventh status line.
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
                .modifier(SettingsRow())

                if model.canConfigureNudges {
                    nudgeToggles
                }
            } header: {
                SectionLabel("Notifications")
            }

            Section {
                StatusBlock(
                    headline: model.storageDescription.headline,
                    detail: model.storageDescription.detail,
                    tone: model.storageIsDegraded ? .warning : .normal
                )
                .modifier(SettingsRow())
                .accessibilityIdentifier("settings.storage")
            } header: {
                SectionLabel("Storage")
            }

            Section {
                StatusBlock(
                    headline: model.syncDescription.headline,
                    detail: model.syncDescription.detail,
                    tone: model.syncStatus.isSyncing ? .normal : .warning
                )
                .modifier(SettingsRow())
                .accessibilityIdentifier("settings.sync")
            } header: {
                SectionLabel("Syncing")
            }

            Section {
                StatusBlock(
                    headline: model.widgetStatus.headline,
                    detail: model.widgetStatus.detail,
                    tone: model.storageIsShared ? .normal : .warning
                )
                .modifier(SettingsRow())
                .accessibilityIdentifier("settings.widgets")
            } header: {
                SectionLabel("Widgets")
            }

            Section {
                // One card rather than four, because these four lines are a single table:
                // the read is down the day counts, not across any one row.
                VStack(alignment: .leading, spacing: Spacing.regular) {
                    ForEach(model.lifetimes, id: \.kind) { entry in
                        HStack(spacing: Spacing.snug) {
                            Image(systemName: KindGlyph.name(for: entry.kind))
                                .font(Typography.caption)
                                .foregroundStyle(Palette.inkMuted)
                                .frame(width: Spacing.loose)
                            Text(entry.kind.rawValue.capitalized)
                                .foregroundStyle(Palette.ink)
                            Spacer(minLength: Spacing.snug)
                            Text("\(entry.days) days")
                                .foregroundStyle(Palette.inkMuted)
                        }
                        .font(Typography.body)
                        .accessibilityElement(children: .combine)
                    }

                    Text("A thought archives itself once it runs out of freshness. Nothing is deleted.")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .modifier(SettingsRow())
                .accessibilityIdentifier("settings.lifetimes")
            } header: {
                SectionLabel("How long things last")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.surface)
        .tint(Palette.accentText)
        .navigationTitle("Settings")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await model.load() }
    }
}

/// The card treatment every settings row shares.
///
/// Settings is a stack of statements about how the app is behaving, and each one is a card. The
/// modifier is what keeps six of them identical without six copies of the same four lines.
private struct SettingsRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, Spacing.regular)
            .listRowInsets(
                EdgeInsets(
                    top: 0, leading: Spacing.loose,
                    bottom: 0, trailing: Spacing.loose
                )
            )
            .listRowSeparator(.hidden)
            .listRowBackground(
                CardSurface()
                    .padding(.horizontal, Spacing.snug)
                    .padding(.vertical, Spacing.tight)
            )
    }
}
