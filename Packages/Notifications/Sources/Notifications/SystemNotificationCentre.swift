import Core
import Foundation
import UserNotifications

/// The real notification centre.
///
/// Marked `@unchecked Sendable` because `UNUserNotificationCenter` is thread-safe but not annotated
/// as `Sendable`; this type holds nothing else.
public struct SystemNotificationCentre: NotificationScheduling, NudgePermissions, @unchecked Sendable {
    private let centre: UNUserNotificationCenter

    /// Creates a wrapper around the system notification centre.
    /// - Parameter centre: The centre to use. Defaults to the current one.
    public init(centre: UNUserNotificationCenter = .current()) {
        self.centre = centre
    }

    public var authorization: NudgeAuthorization {
        get async {
            switch await centre.notificationSettings().authorizationStatus {
            case .notDetermined: .notAsked
            case .denied: .denied
            case .authorized, .provisional, .ephemeral: .allowed
            @unknown default: .denied
            }
        }
    }

    /// Asks for permission.
    ///
    /// Called only from Settings or after a review the user chose to run — never at launch.
    public func request() async -> NudgeAuthorization {
        let granted = try? await centre.requestAuthorization(options: [.alert, .sound])
        return granted == true ? .allowed : .denied
    }

    public func pendingIdentifiers() async -> Set<String> {
        await Set(centre.pendingNotificationRequests().map(\.identifier))
    }

    public func schedule(_ nudge: ScheduledNudge) async {
        let content = UNMutableNotificationContent()
        content.title = nudge.title
        content.body = nudge.body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: nudge.fireAt
        )
        let request = UNNotificationRequest(
            identifier: nudge.id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await centre.add(request)
    }

    public func cancel(_ identifiers: Set<String>) async {
        centre.removePendingNotificationRequests(withIdentifiers: Array(identifiers))
    }
}
