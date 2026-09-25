import Core
import Foundation
import Persistence
import WidgetKit

/// What the freshness widget shows.
struct FreshnessEntry: TimelineEntry {
    /// When this entry describes.
    let date: Date

    /// How many thoughts are still live.
    let liveCount: Int

    /// The most faded live thought, if there is one.
    let fading: String?

    /// How much freshness that thought has left, within 0...1.
    let fadingFreshness: Double

    /// Whether the store could be read at all.
    let isReadable: Bool

    /// Whether this build can access the app's shared storage.
    var isShared: Bool = true

    /// A stand-in used while the real entry loads.
    static func placeholder(at date: Date) -> FreshnessEntry {
        FreshnessEntry(
            date: date,
            liveCount: 4,
            fading: "newsletter about tools that do one thing",
            fadingFreshness: 0.2,
            isReadable: true
        )
    }

    /// The entry shown when the shared store cannot be reached.
    static func unreadable(at date: Date) -> FreshnessEntry {
        FreshnessEntry(date: date, liveCount: 0, fading: nil, fadingFreshness: 0, isReadable: false)
    }
}

/// Reads the shared store on behalf of the widgets.
///
/// Widgets run in their own process, so this goes through exactly the same repository the app uses
/// rather than reading the database a second way.
enum WidgetStore {
    /// Builds the current entry.
    /// - Parameter date: The instant to describe.
    /// - Returns: What the widget should show now.
    static func entry(at date: Date) async -> FreshnessEntry {
        guard ModelContainerFactory.isShared else {
            var entry = FreshnessEntry.unreadable(at: date)
            entry.isShared = false
            return entry
        }
        guard let store = try? ModelContainerFactory.store(syncing: false) else {
            return .unreadable(at: date)
        }

        let repository = SwiftDataThoughtRepository(modelContainer: store.container)
        guard let stored = try? await repository.thoughts(in: .live) else {
            return .unreadable(at: date)
        }

        // The `.live` scope still contains running snoozes, so filter them out here: a thought
        // the user set aside must not be counted on the home screen, and must never be the face
        // the widget shows as the one about to be lost.
        let live = stored.filter { $0.isAwake(at: date) }

        let engine = DecayEngine()
        let mostFaded = live.min {
            engine.freshness(of: $0, at: date).value < engine.freshness(of: $1, at: date).value
        }

        return FreshnessEntry(
            date: date,
            liveCount: live.count,
            fading: mostFaded?.body,
            fadingFreshness: mostFaded.map { engine.freshness(of: $0, at: date).value } ?? 0,
            isReadable: true
        )
    }
}
