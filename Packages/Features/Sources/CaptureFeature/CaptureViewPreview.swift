import Core
import Foundation
import SwiftUI

// The capture screen's preview, and the do-nothing collaborators it needs.
//
// Split out of ``CaptureView`` so the screen's own file stays about the screen: the previews need
// a repository, a classifier and a clock, and three stubs are more lines than the view they
// support.
#Preview {
    CaptureView(
        model: CaptureModel(
            repository: PreviewRepository(),
            intelligence: PreviewIntelligence(),
            clock: PreviewClock()
        )
    )
}

/// Storage that discards everything, so previews need no store.
private actor PreviewRepository: ThoughtRepository {
    func add(_ thought: Thought) async throws {}
    func thoughts(in _: ThoughtScope) async throws -> [Thought] {
        []
    }

    func update(_ thought: Thought) async throws {}
    func delete(id: Thought.ID) async throws {}
}

/// A classifier that decides nothing, so previews need no model.
private struct PreviewIntelligence: IntelligenceService {
    var availability: IntelligenceAvailability {
        .heuristic(reason: .notBuiltIn)
    }

    func classify(_: String) async -> Classification {
        .unknown
    }

    func interviewQuestions(for _: String) async -> [String] {
        []
    }

    func writeUp(
        for _: String,
        answers _: [AnsweredQuestion],
        at _: Date
    ) async -> WriteUp? {
        nil
    }

    func resurfacingLine(for _: String) async -> String? {
        nil
    }
}

/// A clock frozen at a fixed instant, so previews never depend on the system time.
private struct PreviewClock: WallClock {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
}
