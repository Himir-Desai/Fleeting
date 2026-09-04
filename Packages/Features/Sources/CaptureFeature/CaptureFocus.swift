import Foundation
import Observation

/// A request to put the cursor in the capture field.
///
/// The field no longer takes focus by itself on launch, because the habits sharing the home screen
/// would be buried under the keyboard the instant the app opened (ADR-0047). The ambient
/// surfaces — the widget, the lock screen, the Control Center button, Siri — still promise a
/// focused field in one tap, so they say so through this rather than by hoping.
@MainActor
@Observable
public final class CaptureFocus {
    /// How many times focus has been asked for. A count rather than a flag, because two requests
    /// in a row have to read as two separate events.
    public private(set) var requests = 0

    /// Creates a focus request channel with nothing asked for yet.
    public init() {}

    /// Asks the capture field to take focus and raise the keyboard.
    public func request() {
        requests += 1
    }
}
