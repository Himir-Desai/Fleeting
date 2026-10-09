import Core
import DesignSystem
import SwiftUI

/// One collection of lists with stacked sheets for custom-list details and creation.
public struct ThoughtListsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var model: InboxModel
    private let onChange: () -> Void
    private let selectCreatedList: Bool
    private let sharingService: (any ListSharingService)?
    @State private var editing: ThoughtList?
    @State private var creating: ThoughtList?

    public init(
        model: InboxModel,
        selectCreatedList: Bool = true,
        sharingService: (any ListSharingService)? = nil,
        onChange: @escaping () -> Void
    ) {
        self.sharingService = sharingService
        self.model = model
        self.onChange = onChange
        self.selectCreatedList = selectCreatedList
    }

    public var body: some View {
        List {
            Section {
                ForEach(model.lists) { list in
                    if list.isBuiltIn {
                        row(list)
                    } else {
                        Button { editing = list } label: { row(list) }
                            .buttonStyle(PressFeedbackStyle())
                            .accessibilityIdentifier("lists.edit.\(list.id.uuidString)")
                            .swipeActions {
                                if list.sharing == nil {
                                    Button("Delete list", role: .destructive) {
                                        Task { await model.deleteList(list); onChange() }
                                    }
                                }
                            }
                    }
                }
            }
            .listRowBackground(Palette.raised)
            if let error = model.listError {
                Text(error).font(Typography.caption).foregroundStyle(Palette.fading)
            }
        }
        .font(Typography.body)
        .scrollContentBackground(.hidden)
        .background(Palette.surface)
        .accessibilityIdentifier("lists.page")
        .safeAreaInset(edge: .bottom) {
            Button { creating = ThoughtList(name: "") } label: {
                Label("Create list", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .font(Typography.emphasis)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Palette.accent)
            .accessibilityIdentifier("lists.create")
            .padding(Spacing.loose)
            .background(Palette.surface)
        }
        .pageHeading("Lists")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .accessibilityIdentifier("lists.done")
            }
        }
        .sheet(item: $editing) { list in
            NavigationStack {
                ThoughtListEditorView(
                    list: list,
                    isNew: false,
                    model: model,
                    sharingService: sharingService,
                    onChange: onChange
                )
            }
        }
        .sheet(item: $creating) { list in
            NavigationStack {
                ThoughtListEditorView(
                    list: list,
                    isNew: true,
                    model: model,
                    selectOnCreate: selectCreatedList,
                    sharingService: sharingService,
                    onChange: onChange
                )
            }
        }
        .task { model.clearListError(); await model.load() }
    }

    private func row(_ list: ThoughtList) -> some View {
        HStack(spacing: Spacing.regular) {
            VStack(alignment: .leading, spacing: Spacing.tight) {
                Text(list.name).font(Typography.quoted).foregroundStyle(Palette.ink)
                if let sharing = list.sharing {
                    Label(sharing.role == .viewer ? "Shared · View only" : "Shared", systemImage: "person.2")
                        .font(Typography.caption).foregroundStyle(Palette.accentText)
                }
                if !list.description.isEmpty {
                    Text(list.description)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkMuted)
                        .lineLimit(2)
                }
            }
            .padding(.leading, Spacing.tight)
            Spacer(minLength: Spacing.snug)
            if !list.isBuiltIn {
                Image(systemName: "chevron.right")
                    .font(Typography.secondarySymbol)
                    .foregroundStyle(Palette.inkMuted)
            }
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
    }
}
