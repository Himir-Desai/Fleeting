import Foundation

/// Carries a WidgetKit completion handler across an `await`.
///
/// `TimelineProvider` hands back a plain closure and expects it to be called once the entry is
/// ready, which for this app means after reading the store. Swift 6 cannot see that WidgetKit
/// guarantees a single call, so the guarantee is stated here rather than worked around at every
/// call site.
struct WidgetCompletion<Value>: @unchecked Sendable {
    private let handler: (Value) -> Void

    /// Wraps a completion handler.
    /// - Parameter handler: The handler WidgetKit supplied.
    init(_ handler: @escaping (Value) -> Void) {
        self.handler = handler
    }

    /// Calls the wrapped handler.
    /// - Parameter value: What to hand back.
    func callAsFunction(_ value: Value) {
        handler(value)
    }
}
