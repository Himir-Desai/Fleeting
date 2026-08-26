import AppIntents
import SwiftUI
import WidgetKit

/// A Control Center button that opens straight into the capture field.
///
/// The last of the ambient surfaces: a thought can be caught from the home screen, the lock
/// screen, Siri, or Control Center, and all four land on the same focused field.
struct CaptureControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.himirdesai.Fleeting.CaptureControl") {
            ControlWidgetButton(action: OpenCaptureIntent()) {
                Label("Capture", systemImage: "square.and.pencil")
            }
        }
        .displayName("Capture a thought")
        .description("Opens Fleeting with the cursor already in the field.")
    }
}
