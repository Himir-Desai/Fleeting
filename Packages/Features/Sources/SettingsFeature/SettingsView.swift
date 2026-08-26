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
