import Core
import DesignSystem
import SwiftUI

/// Kind and the archive, as a toolbar menu rather than a permanent row of chips.
///
/// Urgency is the list's axis now (ADR-0036), so kind is a secondary question and deserves a
/// secondary affordance. The menu also fixes the chip row running off the trailing edge, which it
/// did on every device narrower than the labels' combined width.
struct InboxFilterMenu: View {
    /// The current selection, written when a menu item is chosen.
    @Binding var filter: InboxFilter

    var body: some View {
        Menu {
            Picker("Show", selection: $filter) {
                Label("All", systemImage: "tray.full")
                    .tag(InboxFilter.all)

                ForEach([ThoughtKind.idea, .todo, .habit], id: \.self) { kind in
                    Label(
                        KindGlyph.pluralLabel(for: kind),
                        systemImage: KindGlyph.name(for: kind)
                    )
                    .tag(InboxFilter.kind(kind))
                }

                Divider()

                Label("Archived", systemImage: "archivebox")
                    .tag(InboxFilter.archived)
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: glyph)
                .accessibilityLabel("Filter thoughts")
        }
        .accessibilityIdentifier("inbox.filterMenu")
    }

    /// The glyph on the control, so the active filter is legible without opening the menu.
    private var glyph: String {
        switch filter {
        case .all: "line.3.horizontal.decrease.circle"
        case let .kind(kind): KindGlyph.name(for: kind)
        case .archived: "archivebox"
        }
    }
}
