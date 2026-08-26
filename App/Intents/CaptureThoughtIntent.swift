import AppIntents
import Core
import Persistence

/// Captures a thought without opening the app.
///
/// The point of the app is that catching a thought costs nothing, and sometimes the cheapest route
/// is not touching the phone at all. Writes through the same repository as everything else.
struct CaptureThoughtIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture a thought"

    static var description: IntentDescription {
        IntentDescription("Saves a thought to Fleeting without opening it.")
    }

    /// The text to capture, exactly as dictated or typed.
    @Parameter(title: "Thought", requestValueDialog: "What's on your mind?")
    var text: String

    /// Stores the thought.
    /// - Returns: A confirmation the system can speak back.
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "There was nothing to save.")
        }

        let container = try ModelContainerFactory.store()
        let repository = SwiftDataThoughtRepository(modelContainer: container)
        try await repository.add(Thought(body: trimmed, capturedAt: SystemClock().now))

        return .result(dialog: "Saved.")
    }
}

/// Teaches Siri the phrase that reaches ``CaptureThoughtIntent``.
struct FleetingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureThoughtIntent(),
            phrases: [
                "Capture a thought in \(.applicationName)",
                "Add to \(.applicationName)"
            ],
            shortTitle: "Capture",
            systemImageName: "square.and.pencil"
        )
    }
}
