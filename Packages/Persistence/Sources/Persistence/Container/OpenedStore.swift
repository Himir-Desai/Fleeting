import Foundation
import SwiftData

/// A store that opened, and what had to be given up to open it.
///
/// Returned rather than thrown so the composition root can report a degraded store quietly
/// instead of failing a launch (ADR-0008).
public struct OpenedStore {
    /// The container to build repositories on.
    public let container: ModelContainer

    /// Whether the store lives in the App Group, and is therefore visible to widgets.
    public let isShared: Bool

    /// Whether the store is backed by iCloud.
    public let cloud: CloudAttachment
}
