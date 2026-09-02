@testable import DesignSystem
import SwiftUI
import Testing

/// That a thought's card expresses how much life it has left.
///
/// The sinking card is the primary reading of freshness (ADR-0035). These tests pin the shape of
/// the slope rather than exact colours, so the palette can be retuned without rewriting them.
@Suite("Freshness as a surface")
struct FreshnessSurfaceTests {
    @Test("a healthy thought has not begun to sink")
    func healthyThoughtDoesNotSink() {
        #expect(FreshnessStyle.sink(for: 1) == 0)
        #expect(FreshnessStyle.sink(for: 0.8) == 0)
        // The threshold itself is still healthy: the slope starts below it, not at it.
        #expect(FreshnessStyle.sink(for: FreshnessStyle.fadingBelow) == 0)
    }

    @Test("sinking rises as freshness runs out")
    func sinkRisesMonotonically() {
        let samples = stride(from: 0.44, through: 0.0, by: -0.04).map {
            FreshnessStyle.sink(for: $0)
        }
        for (earlier, later) in zip(samples, samples.dropFirst()) {
            #expect(later >= earlier, "a thought must never rise back off the page as it ages")
        }
        #expect(FreshnessStyle.sink(for: 0) == 1)
    }

    @Test("sinking is confined to 0...1 for any input")
    func sinkIsClamped() {
        for freshness in [-5.0, -0.1, 0, 0.5, 1, 1.1, 42] {
            let sink = FreshnessStyle.sink(for: freshness)
            #expect(sink >= 0 && sink <= 1, "sink(\(freshness)) escaped 0...1")
        }
    }

    @Test("a card keeps its lift until it is nearly gone, then lies flat")
    func elevationDropsOnlyAtTheEnd() {
        #expect(FreshnessStyle.elevation(for: 1) == .card)
        #expect(FreshnessStyle.elevation(for: 0.5) == .card)
        #expect(FreshnessStyle.elevation(for: FreshnessStyle.expiringBelow) == .card)
        #expect(FreshnessStyle.elevation(for: 0.1) == .flat)
        #expect(FreshnessStyle.elevation(for: 0) == .flat)
    }

    @Test("a fresh card is the raised colour, unblended")
    func freshCardIsRaised() {
        #expect(FreshnessStyle.cardFill(for: 1) == Palette.raised)
    }

    @Test("a card never blends all the way into the page")
    func cardNeverBecomesThePage() {
        // At zero freshness the card is at its deepest. It must still be distinguishable from the
        // page, or a row stops reading as an object and the list loses its edges.
        #expect(FreshnessStyle.maximumSink < 1)
        let deepest = Palette.raisedValues.mixed(
            with: Palette.surfaceValues,
            by: FreshnessStyle.maximumSink
        )
        #expect(deepest.light != Palette.surfaceValues.light)
        #expect(deepest.dark != Palette.surfaceValues.dark)
    }

    @Test("increased contrast keeps every card fully raised")
    func increasedContrastSuppressesTheSink() {
        for freshness in [0.0, 0.1, 0.5, 1.0] {
            #expect(
                FreshnessStyle.cardFill(for: freshness, increasedContrast: true) == Palette.raised,
                "a surface fading into its background is the opposite of increased contrast"
            )
        }
    }
}
