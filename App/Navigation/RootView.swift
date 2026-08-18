import CaptureFeature
import Core
import InboxFeature
import SwiftUI

/// The app's root view.
///
/// Capture is the root, not a destination reached from one, so no screen can precede the field.
/// This is also the only place that knows both features exist: capture asks to browse, and the
/// app decides that browsing means the inbox.
struct RootView: View {
    let environment: AppEnvironment

    @State private var isBrowsing = false

    var body: some View {
        CaptureView(
            model: CaptureModel(
                repository: environment.thoughts,
                clock: environment.clock
            ),
            onBrowse: { isBrowsing = true }
        )
        .sheet(isPresented: $isBrowsing) {
            NavigationStack {
                InboxView(
                    model: InboxModel(
                        repository: environment.thoughts,
                        clock: environment.clock
                    )
                )
            }
        }
    }
}
