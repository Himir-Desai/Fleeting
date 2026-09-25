import Core
import DesignSystem
import SwiftUI

/// A week of short-deadline tasks, with completed items retained on their day.
public struct PlanView: View {
    @Bindable private var model: PlanModel
    @FocusState private var isInputFocused: Bool
    @State private var savedCount = 0
    private let onReview: () -> Void
    private let onOpen: (DailyTodo) -> Void

    public init(
        model: PlanModel, onOpen: @escaping (DailyTodo) -> Void, onReview: @escaping () -> Void
    ) {
        self.model = model
        self.onReview = onReview
        self.onOpen = onOpen
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.loose) {
                    PlanWeekPicker(model: model)
                    completionSummary
                    if !model.pendingReview.isEmpty {
                        Button(action: onReview) {
                            Label(
                                "\(model.pendingReview.count) from earlier days to review",
                                systemImage: "clock.arrow.circlepath"
                            )
                            .font(Typography.subtitle)
                        }
                        .accessibilityIdentifier("plan.review")
                    }
                    if let error = model.error {
                        Text(error).font(Typography.caption).foregroundStyle(Palette.fading)
                        Button("Try again") { Task { await model.load() } }
                    }
                    if model.selectedDay < model.today {
                        Text("Tasks added to an earlier day also appear in Review.")
                            .font(Typography.caption).foregroundStyle(Palette.inkMuted)
                    }
                    if !model.hasLoaded {
                        ProgressView()
                    }
                    checklist
                }
                .padding(Spacing.loose)
            }
            .background(Palette.surface.ignoresSafeArea())
            .navigationTitle("Plan")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem {
                        Button("Today") { model.showToday() }
                            .accessibilityIdentifier("plan.today")
                    }
                    #if os(iOS)
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { isInputFocused = false }
                                .accessibilityIdentifier("plan.dismissKeyboard")
                        }
                    #endif
                }
                .scrollDismissesKeyboard(.interactively)
                .task { await model.load() }
                .refreshable { await model.load() }
                .onChange(of: savedCount) { _, _ in
                    proxy.scrollTo("plan.composer", anchor: .bottom)
                }
        }
    }

    private var completionSummary: some View {
        Text("\(model.selectedTodos.filter(\.isDone).count) of \(model.selectedTodos.count) done")
            .font(Typography.caption).foregroundStyle(Palette.inkMuted)
    }

    private var checklist: some View {
        VStack(spacing: Spacing.snug) {
            ForEach(model.selectedTodos) { todo in
                PlanTodoRow(
                    todo: todo,
                    disabled: model.busyIDs.contains(todo.id),
                    onOpen: { onOpen(todo) },
                    action: {
                        Task { await model.decide(todo, todo.isDone ? .reopen : .finish) }
                    }
                )
                .contextMenu {
                    Button("Edit", systemImage: "pencil") { onOpen(todo) }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        Task { await model.delete(todo) }
                    }
                }
                .transition(.opacity)
                Divider().overlay(Palette.separator)
            }
            composer
                .id("plan.composer")
        }
        .motion(Motion.commit, value: model.selectedTodos.map(\.id))
    }

    /// Saves this row and keeps the following blank row ready for the next task.
    private func submit() {
        Task {
            guard await model.add() else { return }
            isInputFocused = true
            savedCount += 1
        }
    }

    private var composer: some View {
        HStack(alignment: .center, spacing: Spacing.regular) {
            Image(systemName: "circle")
                .font(Typography.body)
                .foregroundStyle(Palette.inkMuted)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityHidden(true)
            TextField("One thing to do…", text: $model.draft, axis: .vertical)
                .focused($isInputFocused)
                .font(Typography.serifBody)
                .foregroundStyle(Palette.ink)
                .frame(minHeight: 44)
                .lineLimit(1 ... 4)
                .submitLabel(.next)
                .onSubmit(submit)
                .accessibilityIdentifier("plan.input")
            Button(action: submit) {
                Image(systemName: "plus").font(Typography.body)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!model.canAdd || model.isSaving)
            .accessibilityLabel("Add task")
            .accessibilityIdentifier("plan.add")
        }
        .frame(minHeight: 44)
    }
}
