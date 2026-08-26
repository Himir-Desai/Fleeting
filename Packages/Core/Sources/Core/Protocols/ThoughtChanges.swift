import Foundation

/// Announces that stored thoughts have changed, so screens already on display can refresh.
///
/// Needed because work that deliberately outlives a save — classification above all — finishes
/// after the screen that started it has moved on.
public protocol ThoughtChangeObserving: Sendable {
    /// Yields once every time stored thoughts change.
    var changes: AsyncStream<Void> { get }
}

/// Broadcasts change notifications to every listening screen.
///
/// Marked `@unchecked Sendable` because its mutable state is a dictionary of continuations guarded
/// by an `NSLock`. An actor would be the usual answer, but `changes` must be reachable
/// synchronously from a SwiftUI view body, which cannot await.
public final class ThoughtChangeNotifier: ThoughtChangeObserving, @unchecked Sendable {
    private let lock = NSLock()
    private var listeners: [UUID: AsyncStream<Void>.Continuation] = [:]

    /// Creates a notifier with no listeners.
    public init() {}

    public var changes: AsyncStream<Void> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            listeners[id] = continuation
            lock.unlock()

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.lock()
                listeners[id] = nil
                lock.unlock()
            }
        }
    }

    /// Tells every listener that stored thoughts have changed.
    public func notify() {
        lock.lock()
        let current = Array(listeners.values)
        lock.unlock()
        for continuation in current {
            continuation.yield()
        }
    }
}
