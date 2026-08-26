import Core
import Foundation
import Intelligence

/// Chooses which intelligence implementation the app runs with.
///
/// The only place that decides; every other layer sees ``Core/IntelligenceService`` and never asks
/// what the device is capable of.
enum IntelligenceFactory {
    /// Builds the classifier for this device.
    /// - Returns: The on-device model when the SDK provides one, always wrapped so that a missing,
    ///   slow, or wrong model degrades to rules rather than failing.
    static func make() -> any IntelligenceService {
        #if canImport(FoundationModels)
            if #available(iOS 26, macOS 26, *) {
                return ResilientIntelligence(
                    primary: FoundationModelsIntelligence(),
                    fallback: HeuristicIntelligence(reason: .requestFailed)
                )
            }
        #endif
        return ResilientIntelligence(
            primary: nil,
            fallback: HeuristicIntelligence(reason: .notBuiltIn)
        )
    }
}
