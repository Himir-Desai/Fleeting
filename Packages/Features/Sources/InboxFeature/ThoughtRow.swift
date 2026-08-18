import Core
import DesignSystem
import SwiftUI

/// One thought in the inbox list.
///
/// Deliberately plain in Phase 1. Phase 2 replaces the timestamp with a freshness treatment.
struct ThoughtRow: View {
    let thought: Thought

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            Text(thought.body)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .lineLimit(3)

            Text(thought.capturedAt, format: .relative(presentation: .named))
                .font(Typography.caption)
                .foregroundStyle(Palette.inkMuted)
        }
        .padding(.vertical, Spacing.tight)
        .listRowBackground(Palette.raised)
    }
}
