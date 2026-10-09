import Foundation

/// The current person's permissions on a live shared list.
public struct ListSharing: Equatable, Hashable, Sendable {
    public enum Role: String, Sendable { case owner, editor, viewer }
    public let role: Role
    public let ownerName: String?

    public var canEdit: Bool {
        role != .viewer
    }

    public var isOwner: Bool {
        role == .owner
    }

    /// The access summary used to distinguish same-named lists from different owners.
    public var summary: String {
        let origin = role == .owner ? "Shared" : ownerName.map { "Shared by \($0)" } ?? "Shared"
        return role == .viewer ? "\(origin) · View only" : origin
    }

    public init(role: Role, ownerName: String? = nil) {
        self.role = role
        self.ownerName = ownerName
    }
}
