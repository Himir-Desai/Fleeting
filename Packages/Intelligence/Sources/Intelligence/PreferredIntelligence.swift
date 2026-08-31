import Core
import Foundation

/// Routes classification according to what the user asked for in Settings.
///
/// Wraps the resilient classifier rather than replacing it: when the user has chosen rules, the
/// model is never consulted at all, and when they have chosen automatic this defers entirely to
/// whatever the device can actually do. The preference is read on every call, so changing it in
/// Settings takes effect on the very next capture without relaunching (ADR-0030).
public struct PreferredIntelligence: IntelligenceService {
    private let automatic: any IntelligenceService
    private let rules: any IntelligenceService
    private let preference: @Sendable () -> SortingPreference

    /// Creates the router.
    /// - Parameters:
    ///   - automatic: Used when the user wants the model where available.
    ///   - rules: Used when the user has asked for rules only.
    ///   - preference: Read on every call, so a change applies immediately.
    public init(
        automatic: any IntelligenceService,
        rules: any IntelligenceService,
        preference: @escaping @Sendable () -> SortingPreference
    ) {
        self.automatic = automatic
        self.rules = rules
        self.preference = preference
    }

    /// Whichever implementation the preference currently selects.
    private var chosen: any IntelligenceService {
        preference() == .rulesOnly ? rules : automatic
    }

    public var availability: IntelligenceAvailability {
        get async {
            // A deliberate choice is reported as a choice, never as a failure to reach a model.
            guard preference() != .rulesOnly else {
                return .heuristic(reason: .userChose)
            }
            return await automatic.availability
        }
    }

    public func classify(_ text: String) async -> Classification {
        await chosen.classify(text)
    }

    public func interviewQuestions(for text: String) async -> [String] {
        await chosen.interviewQuestions(for: text)
    }

    public func writeUp(
        for text: String,
        answers: [AnsweredQuestion],
        at date: Date
    ) async -> WriteUp? {
        await chosen.writeUp(for: text, answers: answers, at: date)
    }

    public func resurfacingLine(for text: String) async -> String? {
        await chosen.resurfacingLine(for: text)
    }
}
