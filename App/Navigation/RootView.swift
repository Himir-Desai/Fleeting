import ArchiveFeature
import CaptureFeature
import Core
import InboxFeature
import SettingsFeature
import SharpenFeature
import SwiftUI

/// The app's root view.
///
/// Capture is the root, not a destination reached from one, so no screen can precede the field.
/// This is also the only place that knows every feature exists: capture asks to browse and the
/// inbox asks for the archive, and the app decides what each of those means.
struct RootView: View {
    let environment: AppEnvironment

    @State private var isBrowsing = false
    @State private var isShowingArchive = false
    @State private var isShowingSettings = false
    @State private var sharpening: Thought?

    var body: some View {
        CaptureView(
            model: CaptureModel(
                repository: environment.thoughts,
                intelligence: environment.intelligence,
                changes: environment.changes,
                clock: environment.clock
            ),
            onBrowse: { isBrowsing = true }
        )
        .sheet(isPresented: $isBrowsing) {
            NavigationStack {
                InboxView(
                    model: InboxModel(
                        repository: environment.thoughts,
                        sweeper: environment.sweeper,
                        engine: environment.engine,
                        clock: environment.clock
                    ),
                    changes: environment.changes,
                    onOpenArchive: { isShowingArchive = true },
                    onOpenSettings: { isShowingSettings = true },
                    onSharpen: { sharpening = $0 }
                )
                .navigationDestination(item: $sharpening) { thought in
                    SharpenView(
                        model: SharpenModel(
                            thought: thought,
                            repository: environment.thoughts,
                            intelligence: environment.intelligence,
                            changes: environment.changes,
                            clock: environment.clock
                        )
                    )
                }
                .navigationDestination(isPresented: $isShowingArchive) {
                    ArchiveView(
                        model: ArchiveModel(
                            repository: environment.thoughts,
                            clock: environment.clock
                        )
                    )
                }
                .navigationDestination(isPresented: $isShowingSettings) {
                    SettingsView(
                        model: SettingsModel(
                            intelligence: environment.intelligence,
                            profiles: environment.engine.profiles
                        )
                    )
                }
            }
        }
        // Runs after the field is on screen, never before it.
        .task { await environment.prepare() }
    }
}
