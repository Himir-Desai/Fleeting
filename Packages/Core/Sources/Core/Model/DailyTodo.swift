import Foundation

/// A dated checklist projection of a shared thought to-do.
public struct DailyTodo: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let createdAt: Date
    public private(set) var day: PlanDay
    public private(set) var completedAt: Date?

    public init(
        id: UUID = UUID(), text: String, createdAt: Date, day: PlanDay, completedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.day = day
        self.completedAt = completedAt
    }

    public var isDone: Bool {
        completedAt != nil
    }

    /// Whether an unfinished task from an earlier day needs a decision.
    public func needsReview(on today: PlanDay) -> Bool {
        !isDone && day < today
    }

    /// Applies an explicit decision without moving completed tasks or rolling forward twice.
    public mutating func apply(_ decision: DailyTodoDecision, today: PlanDay, at date: Date) {
        switch decision {
        case .finish:
            if completedAt == nil {
                completedAt = date
            }
        case .reopen:
            completedAt = nil
        case .carryForward:
            if needsReview(on: today) {
                day = today
            }
        }
    }
}

/// A person's decision about a dated task.
public enum DailyTodoDecision: Sendable {
    case finish
    case reopen
    case carryForward
}
