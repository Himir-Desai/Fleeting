import Foundation

/// A named collection of thoughts, including the built-in dated Plan list.
public struct ThoughtList: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var defaultKind: ThoughtKind
    public var sharing: ListSharing?

    /// Stable across devices without creating a separate built-in record.
    public static let planID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    public static let plan = ThoughtList(id: planID, name: "Plan", defaultKind: .todo)

    public var isBuiltIn: Bool {
        id == Self.planID
    }

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        defaultKind: ThoughtKind = .unsorted,
        sharing: ListSharing? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.defaultKind = defaultKind
        self.sharing = sharing
    }
}
