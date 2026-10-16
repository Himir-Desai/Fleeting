import Core
import DesignSystem
import SwiftUI

/// One row in the Archived filter: the thought's words and when it was captured, with restore and
/// permanent delete as swipes.
///
/// Tapping opens the restricted thought editor; restore and delete remain available as swipes.
struct ArchivedListRow: View {
    let thought: Thought
    let onOpen: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Spacing.tight) {
                Text(thought.body)
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink)
                    .strikethrough(thought.isCompleted)
                    .lineLimit(3)
                Text("captured \(thought.capturedAt, format: .relative(presentation: .named))")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressFeedbackStyle())
        .accessibilityIdentifier("row.openArchived")
        .padding(.vertical, Spacing.snug)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .listRowInsets(
            EdgeInsets(top: 0, leading: Spacing.loose, bottom: 0, trailing: Spacing.loose)
        )
        .listRowSeparator(.hidden)
        .listRowBackground(
            CardSurface(elevation: .flat)
                .padding(.horizontal, Spacing.snug)
                .padding(.vertical, Spacing.tight)
        )
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if thought.canEditContent {
                Button(action: onRestore) {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                }
                .tint(Palette.accent)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if thought.canEditContent {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
