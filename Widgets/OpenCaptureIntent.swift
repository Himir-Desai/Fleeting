import AppIntents

/// Opens Fleeting on the capture field.
///
/// Used by the Control Center control, which cannot open the app on its own. Deliberately does no
/// work of its own: the app's cold-launch path already lands on a focused field, so anything here
/// would only get in the way of it (ADR-0008).
struct OpenCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture a thought"

    static var description: IntentDescription {
        IntentDescription("Opens Fleeting with the cursor already in the field.")
    }

    /// Computed rather than stored, because the protocol asks for a settable static and a
    /// stored one would be global mutable state under strict concurrency. The setter is empty
    /// on purpose: this intent only ever opens the app.
    static var openAppWhenRun: Bool {
        get { true }
        set {}
    }

    func perform() async throws -> some IntentResult {
        .result()
    }
}
