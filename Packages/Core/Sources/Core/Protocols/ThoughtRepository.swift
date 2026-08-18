import Foundation

/// Storage for captured thoughts.
///
/// Declared here and implemented above, so the domain never depends on a storage technology.
public protocol ThoughtRepository: Sendable {
    /// Stores a newly captured thought.
    /// - Parameter thought: The thought to store.
    func add(_ thought: Thought) async throws

    /// Every stored thought, most recently captured first.
    /// - Returns: All thoughts, including archived ones.
    func all() async throws -> [Thought]

    /// Replaces a stored thought with an updated copy.
    /// - Parameter thought: The thought to store in place of the existing one.
    func update(_ thought: Thought) async throws

    /// Permanently removes a thought. Only ever called for an explicit human deletion.
    /// - Parameter id: Identity of the thought to remove.
    func delete(id: Thought.ID) async throws
}
