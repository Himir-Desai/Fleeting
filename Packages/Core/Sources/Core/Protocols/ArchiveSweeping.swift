import Foundation

/// Archives thoughts that have run out of freshness.
///
/// Declared here so features can trigger a sweep without depending on the storage layer that
/// implements it.
public protocol ArchiveSweeping: Sendable {
    /// Archives every live thought whose freshness has reached zero.
    /// - Returns: The thoughts that were archived.
    @discardableResult
    func sweep() async throws -> [Thought]
}
