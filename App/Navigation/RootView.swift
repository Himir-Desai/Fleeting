import ArchiveFeature
import CaptureFeature
import Core
import InboxFeature
import ReviewFeature
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
    @State private var isReviewing = false

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
                    onSharpen: { sharpening = $0 },
                    onReview: { isReviewing = true }
                )
                .navigationDestination(isPresented: $isReviewing) {
                    ReviewView(
                        model: ReviewModel(
                            repository: environment.thoughts,
                            selector: ReviewSelector(engine: environment.engine),
                            engine: environment.engine,
                            intelligence: environment.intelligence,
                            changes: environment.changes,
                            clock: environment.clock
                        )
                    )
                }
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
                            profiles: environment.engine.profiles,
                            storageIsShared: environment.storageIsShared,
                            sync: environment.sync,
                            store: environment.nudgePreferences,
                            permissions: environment.nudgePermissions,
                            onNudgesChanged: { await environment.refreshNudges() }
                        )
                    )
                }
            }
        }
        // Runs after the field is on screen, never before it.
        .task { await environment.prepare() }
        .task {
            // Copy is written ahead of time, so the queue is rebuilt whenever the store might
            // have moved on. Never before the field is on screen.
            for await _ in environment.changes.changes {
                await environment.refreshNudges()
            }
        }
    }
}
