import Foundation

/// Storage for captured thoughts.
///
/// Declared here and implemented above, so the domain never depends on a storage technology.
public protocol ThoughtRepository: Sendable {
    /// Stores a newly captured thought.
    /// - Parameter thought: The thought to store.
    func add(_ thought: Thought) async throws

    /// Stored thoughts within a lifecycle scope, most recently captured first.
    /// - Parameter scope: Which part of the collection to read.
    /// - Returns: Matching thoughts, newest capture first.
    func thoughts(in scope: ThoughtScope) async throws -> [Thought]

    /// Replaces a stored thought with an updated copy.
    /// - Parameter thought: The thought to store in place of the existing one.
    func update(_ thought: Thought) async throws

    /// Permanently removes a thought. Only ever called for an explicit human deletion.
    /// - Parameter id: Identity of the thought to remove.
    func delete(id: Thought.ID) async throws
}

public extension ThoughtRepository {
    /// Every stored thought, regardless of lifecycle position.
    /// - Returns: All thoughts, newest capture first.
    func all() async throws -> [Thought] {
        try await thoughts(in: .all)
    }

    /// Thoughts whose raw captured text contains the query.
    ///
    /// A correct default that filters in memory. Implementations backed by a real store should
    /// override this to push the match down to the store.
    /// - Parameters:
    ///   - query: Text to look for. Blank queries return the whole scope.
    ///   - scope: Which part of the collection to search.
    /// - Returns: Matching thoughts, newest capture first.
    func search(_ query: String, in scope: ThoughtScope) async throws -> [Thought] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try await thoughts(in: scope) }
        return try await thoughts(in: scope).filter {
            $0.body.localizedStandardContains(trimmed)
        }
    }
}
