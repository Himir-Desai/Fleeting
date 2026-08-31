import Core
import DesignSystem
import SwiftUI

/// The row of filters above the thoughts list: All, one per kind, then Archived.
///
/// Its own view rather than a property of `InboxView` because the chips are a self-contained
/// control — they read one selection and write one selection, and nothing else on the screen.
struct FilterChipRow: View {
    /// The current selection, written when a chip is tapped.
    @Binding var filter: InboxFilter
    /// How many live thoughts there are, shown on the All chip.
    let liveCount: Int
    /// How many archived thoughts there are, shown on the Archived chip.
    let archivedCount: Int
    /// How many live thoughts of a kind there are, shown on that kind's chip.
    let countOfKind: (ThoughtKind) -> Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.snug) {
                FilterChip(
                    systemImage: "tray.full",
                    label: "All",
                    count: liveCount,
                    isSelected: filter == .all
                ) { filter = .all }
                    .accessibilityIdentifier("inbox.filter.all")

                ForEach([ThoughtKind.idea, .todo, .habit], id: \.self) { kind in
                    FilterChip(
                        systemImage: KindGlyph.name(for: kind),
                        label: Self.pluralLabel(for: kind),
                        count: countOfKind(kind),
                        isSelected: filter == .kind(kind)
                    ) { filter = .kind(kind) }
                        .accessibilityIdentifier("inbox.filter.\(kind.rawValue)")
                }

                FilterChip(
                    systemImage: "archivebox",
                    label: "Archived",
                    count: archivedCount,
                    isSelected: filter == .archived
                ) { filter = .archived }
                    .accessibilityIdentifier("inbox.filter.archived")
            }
            .padding(.vertical, Spacing.tight)
        }
        .accessibilityIdentifier("inbox.filters")
    }

    /// The plural chip label for a kind.
    /// - Parameter kind: The kind being labelled.
    /// - Returns: The label shown on that kind's chip.
    static func pluralLabel(for kind: ThoughtKind) -> String {
        switch kind {
        case .idea: "Ideas"
        case .todo: "To-dos"
        case .habit: "Habits"
        case .unsorted: "Unsorted"
        }
    }
}
