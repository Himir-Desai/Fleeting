import Core
import DesignSystem
import SwiftUI

/// Native sharing entry point with its explanation grouped beneath the action.
struct ThoughtListSharingControls: View {
    let list: ThoughtList
    @Bindable var model: InboxModel
    let service: any ListSharingService
    @Binding var isSharing: Bool
    let isSaving: Bool
    let hasInvalidName: Bool
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            Button {
                isSharing = true
                Task {
                    let unchanged = model.lists.first { $0.id == list.id } == list
                    let saved = list.sharing?.canEdit == false || unchanged ? true : await model
                        .saveList(list)
                    if saved {
                        onChange()
                        await service.shareList(list)
                    }
                    isSharing = false
                }
            } label: {
                HStack(spacing: Spacing.regular) {
                    Label(
                        list.sharing == nil ? "Share List" : "Manage Sharing",
                        systemImage: "person.crop.circle.badge.plus"
                    )
                    if isSharing {
                        ProgressView()
                    }
                }
            }
            .font(Typography.body)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Palette.accentText)
            .disabled(isSharing || isSaving || (list.sharing == nil && hasInvalidName))
            .accessibilityIdentifier("lists.share")
            Text(explanation).font(Typography.caption).foregroundStyle(Palette.inkMuted)
        }
    }

    private var explanation: String {
        guard let sharing = list.sharing
        else { return "Invite people to view or edit this list through iCloud." }
        let action = sharing.isOwner ? "Manage access or stop sharing." : "View participants or leave."
        return "Archive shared thoughts manually. \(action) Streaks and hiding stay personal."
    }
}
