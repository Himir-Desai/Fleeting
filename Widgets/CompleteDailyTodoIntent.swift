import AppIntents
import Core
import Foundation
import Persistence
import WidgetKit

/// Marks a task done without opening the app or toggling an already-completed task back.
struct CompleteDailyTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "Finish daily task"

    @Parameter(title: "Task") var taskID: String

    init() {}
    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        guard ModelContainerFactory.isShared, let id = UUID(uuidString: taskID) else {
            throw CompletionError.unavailable
        }
        let store = try ModelContainerFactory.store(syncing: false)
        let repository = SwiftDataDailyTodoRepository(modelContainer: store.container)
        let now = SystemClock().now
        try await repository.decide(id: id, decision: .finish, today: PlanDay(now), at: now)
        WidgetCenter.shared.reloadTimelines(ofKind: "FleetingDailyPlan")
        WidgetCenter.shared.reloadTimelines(ofKind: "FleetingTomorrowPlan")
        return .result()
    }

    enum CompletionError: LocalizedError {
        case unavailable
        var errorDescription: String? {
            "Open Fleeting to update this task. Shared storage is unavailable."
        }
    }
}
