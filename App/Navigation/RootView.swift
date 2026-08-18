import CaptureFeature
import SwiftUI

/// The app's root view.
///
/// Capture is the root, not a destination reached from one. Any future navigation is pushed
/// or presented *from* here, so no screen can ever precede the capture field.
struct RootView: View {
    let environment: AppEnvironment

    var body: some View {
        CaptureView(
            model: CaptureModel(
                repository: environment.thoughts,
                clock: environment.clock
            )
        )
    }
}
