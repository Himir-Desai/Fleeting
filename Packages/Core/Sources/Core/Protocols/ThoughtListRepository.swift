import Foundation

/// Stores named lists alongside thoughts. Removing a list unfiles its thoughts without deleting them.
public protocol ThoughtListRepository: Sendable {
    func lists() async throws -> [ThoughtList]
    func saveList(_ list: ThoughtList) async throws
    func deleteList(id: UUID) async throws
}

/// Invalid or protected list edits.
public enum ThoughtListError: Error, Equatable, Sendable {
    case emptyName
    case duplicateName
    case builtInList
}

public extension ThoughtListRepository {
    /// Creates a list after trimming and validating its name.
    func createList(
        named name: String,
        description: String = "",
        defaultKind: ThoughtKind = .unsorted
    ) async throws -> ThoughtList {
        let list = ThoughtList(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description,
            defaultKind: defaultKind
        )
        try await saveList(list)
        return list
    }
}
