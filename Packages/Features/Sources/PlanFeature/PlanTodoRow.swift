import Core
import DesignSystem
import SwiftUI

/// A checklist row whose completion line draws across the task's words.
struct PlanTodoRow: View {
    let todo: DailyTodo
    let disabled: Bool
    var onOpen: (() -> Void)?
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.regular) {
            Button(action: action) {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isDone ? Palette.accentText : Palette.inkMuted)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(todo.text)
            .accessibilityValue(todo.isDone ? "Done" : "Not done")
            .accessibilityHint(todo.isDone ? "Mark as not done" : "Mark as done")
            .accessibilityIdentifier("plan.task.\(todo.id)")
            if let onOpen {
                Button(action: onOpen) {
                    HStack {
                        PlanTaskText(text: todo.text, isDone: todo.isDone)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(Typography.caption).foregroundStyle(Palette.inkMuted)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Edit \(todo.text)")
                .accessibilityIdentifier("plan.open.\(todo.id)")
            } else {
                PlanTaskText(text: todo.text, isDone: todo.isDone)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .motion(Motion.decay, value: todo.isDone)
        .sensoryFeedback(.success, trigger: todo.isDone)
    }
}
