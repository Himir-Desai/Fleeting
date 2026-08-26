import Foundation

/// Whether the app is permitted to send notifications.
public enum NudgeAuthorization: String, Equatable, Sendable {
    /// The user has never been asked. Nothing is scheduled in this state.
    case notAsked
    /// Notifications are permitted.
    case allowed
    /// The user said no. Never asked again from inside the app.
    case denied

    /// Whether anything may be scheduled.
    public var permitsScheduling: Bool {
        self == .allowed
    }
}

/// Asks for, and reports, permission to send notifications.
///
/// Permission is requested lazily and never at launch: nothing may stand between a cold launch and
/// a focused capture field (ADR-0008).
public protocol NudgePermissions: Sendable {
    /// The current permission state.
    var authorization: NudgeAuthorization { get async }

    /// Asks the user for permission.
    /// - Returns: The resulting state, whatever they chose.
    func request() async -> NudgeAuthorization
}
