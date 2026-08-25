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
            RootView(environment: environment)
                // The palette is dark-only for now; a proper light-mode pass is Phase 8 work.
                .preferredColorScheme(.dark)
        }
    }
}
