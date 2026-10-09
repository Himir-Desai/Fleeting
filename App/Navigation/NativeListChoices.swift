import Core
import DesignSystem
import SwiftUI

/// Domain values for the shared choices popover attached to the native Lists tab.
struct NativeListChoices: View {
    let lists: [ThoughtList]
    let selectedID: UUID?
    let onSelect: (UUID?) -> Void
    let onCreate: () -> Void
    let onEdit: () -> Void

    var body: some View {
        ListSelectionChoices(
            choices: lists.map { .init(id: $0.id.uuidString, name: $0.name, detail: $0.sharing?.summary) },
            selection: selectedID?.uuidString,
            onSelect: {
                onSelect($0.flatMap(UUID.init(uuidString:)))
            },
            onAdd: onCreate,
            onEdit: onEdit
        )
        .accessibilityIdentifier("inbox.listChoices")
    }
}
