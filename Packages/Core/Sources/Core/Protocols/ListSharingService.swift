import Foundation

/// Opens the system invitation and participant-management UI for a collection.
@MainActor
public protocol ListSharingService: AnyObject {
    func shareList(_ list: ThoughtList) async
}

/// Sharing and permission failures that can be shown in list or thought properties.
public enum ListSharingError: Error, LocalizedError, Sendable {
    case unavailable
    case signInRequired
    case readOnly
    case protectedList
    case stopSharingFirst
    case moveSharedThought
    case timedOut
    case invalidInvitation

    public var errorDescription: String? {
        switch self {
        case .unavailable: "iCloud sharing isn’t available on this device. Your private thoughts stay saved."
        case .signInRequired: "Sign in to iCloud in Settings to share this list."
        case .readOnly: "You have view-only access to this list."
        case .protectedList: "Share a custom list. Your personal Plan stays private."
        case .stopSharingFirst: "Stop sharing before deleting this list. Its thoughts will be kept."
        case .moveSharedThought: "Copy the text into a new thought to move into or out of a shared list."
        case .timedOut: "iCloud is taking longer than expected. Check your connection and try again."
        case .invalidInvitation: "This invitation belongs to a different app."
        }
    }
}
