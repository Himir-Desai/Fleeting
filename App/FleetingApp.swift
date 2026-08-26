import SwiftUI

/// The application entry point.
///
/// Its only job is to build the composition root and hand it to the root view. Per ADR-0008
/// there is nothing between launch and the capture screen — no gate, no prompt, no splash.
@main
struct FleetingApp: App {
    private let environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            // No `preferredColorScheme`: the palette adapts, so the app looks the way the user
            // has asked their phone to look rather than overriding it (ADR-0020).
            RootView(environment: environment)
        }
    }
}
