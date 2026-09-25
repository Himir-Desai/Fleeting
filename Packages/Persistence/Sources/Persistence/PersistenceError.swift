import Core
import Foundation

/// Failures the storage layer can report to the domain.
public enum PersistenceError: Error, Equatable {
    /// No stored thought matches the given identity.
    case thoughtNotFound(Thought.ID)
    /// No stored checklist task matches the given identity.
    case dailyTodoNotFound(UUID)
}
