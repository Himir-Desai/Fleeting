import CaptureFeature
import Core
import InboxFeature
import ReviewFeature
import SettingsFeature
import SharpenFeature
import SwiftUI

/// The app's root view.
///
/// Three tabs — a new thought, existing thoughts, and settings — with the new-thought tab selected
/// on launch, so a cold launch still lands on the capture field with nothing before it (ADR-0008).
/// This is also the only place that knows every feature exists, so it wires what each tab reaches.
struct RootView: View {
    let environment: AppEnvironment

    /// Which tab is showing. New thought is first, so it is where a cold launch lands.
    private enum AppTab: Hashable {
        case newThought
        case thoughts
        case settings
    }

    @State private var selection: AppTab = .newThought
    @State private var opened: Thought?
    @State private var sharpening: Thought?
    @State private var isReviewing = false

    var body: some View {
        TabView(selection: $selection) {
            Tab("New thought", systemImage: "square.and.pencil", value: AppTab.newThought) {
                CaptureView(
                    model: CaptureModel(
                        repository: environment.thoughts,
                        intelligence: environment.intelligence,
                        changes: environment.changes,
                        clock: environment.clock
                    )
                )
            }

            Tab("Thoughts", systemImage: "tray.full", value: AppTab.thoughts) {
                thoughtsTab
            }

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack {
                    settings
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

    /// The existing-thoughts tab: the inbox, with a thought's detail, a review and sharpening
    /// reachable from it as pushes. The archive is a filter within the inbox, not a page.
    private var thoughtsTab: some View {
        NavigationStack {
            InboxView(
                model: InboxModel(
                    repository: environment.thoughts,
                    sweeper: environment.sweeper,
                    engine: environment.engine,
                    clock: environment.clock
                ),
                changes: environment.changes,
                storageIsDegraded: environment.storageIsDegraded,
                onReview: { isReviewing = true },
                onOpen: { opened = $0 }
            )
            .navigationDestination(item: $opened) { thought in
                ThoughtDetailView(
                    model: ThoughtDetailModel(
                        thought: thought,
                        repository: environment.thoughts,
                        changes: environment.changes,
                        clock: environment.clock
                    ),
                    onEnhance: { sharpening = thought }
                )
            }
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
        }
    }

    /// The settings tab.
    private var settings: some View {
        SettingsView(
            model: SettingsModel(
                intelligence: environment.intelligence,
                profiles: environment.engine.profiles,
                storageIsShared: environment.storageIsShared,
                storageIsDegraded: environment.storageIsDegraded,
                sync: environment.sync,
                store: environment.nudgePreferences,
                permissions: environment.nudgePermissions,
                onNudgesChanged: { await environment.refreshNudges() }
            )
        )
    }
}
