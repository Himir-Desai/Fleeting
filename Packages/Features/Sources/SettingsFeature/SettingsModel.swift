import Core
import Foundation
import Observation

/// State for the settings screen.
@MainActor
@Observable
public final class SettingsModel {
    /// What is currently sorting captured thoughts, or `nil` until asked.
    public private(set) var availability: IntelligenceAvailability?

    /// The decay rates in force, one per kind.
    public let profiles: DecayProfiles

    private let intelligence: any IntelligenceService

    /// Creates the settings screen's state.
    /// - Parameters:
    ///   - intelligence: Asked what is currently answering.
    ///   - profiles: The decay rates to display.
    public init(intelligence: any IntelligenceService, profiles: DecayProfiles) {
        self.intelligence = intelligence
        self.profiles = profiles
    }

    /// Asks the intelligence layer what is currently answering.
    public func load() async {
        availability = await intelligence.availability
    }

    /// How the current intelligence state should be described to the user.
    /// - Returns: A headline and a supporting sentence.
    public var status: (headline: String, detail: String) {
        switch availability {
        case .onDevice:
            ("On-device model", "Sorting happens on this iPhone. Nothing is sent anywhere.")
        case let .heuristic(reason):
            ("Rules", reason.summary + " Sorting still works, it is just simpler.")
        case nil:
            ("Checking…", "")
        }
    }

    /// How long each kind of thought lasts before archiving.
    /// - Returns: A label and a day count per kind, in the order shown.
    public var lifetimes: [(kind: ThoughtKind, days: Int)] {
        ThoughtKind.allCases.map { kind in
            (kind, Int(profiles.policy(for: kind).lifetime / .day))
        }
    }
}
