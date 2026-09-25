import CaptureFeature
import Core
import DesignSystem
import InboxFeature
import PlanFeature
import ReviewFeature
import SettingsFeature
import SharpenFeature
import SwiftUI
import WidgetKit

/// The app's root view.
///
/// Five tabs — home, thoughts, plan, review, and settings — with home selected on launch, so a
/// cold launch still lands on the capture field with nothing before it (ADR-0008). Home carries
/// today's habits under that field, because a habit is the one thing here that needs daily
/// attention (ADR-0047). This is also the only place that knows every feature exists, so it wires
/// what each tab reaches.
struct RootView: View {
    let environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @State private var plan: PlanModel
    @State private var reviewTasks = false
    @State private var planOpened: Thought?
    @State private var planSharpening: Thought?

    init(environment: AppEnvironment) {
        self.environment = environment
        _plan = State(initialValue: PlanModel(
            repository: environment.dailyTodos, changes: environment.dailyChanges, clock: environment.clock
        ))
    }

    /// Which tab is showing. New thought is first, so it is where a cold launch lands.
    private enum AppTab: Hashable {
        case newThought
        case thoughts
        case plan
        case review
        case settings
    }

    @State private var selection: AppTab = .newThought
    @State private var opened: Thought?
    @State private var sharpening: Thought?
    @State private var isReviewing = false

    /// Asked by the widget, the lock screen and Control Center to put the cursor in the field.
    /// A plain launch never asks, so a plain launch shows the habits instead (ADR-0047).
    @State private var captureFocus = CaptureFocus()

    /// Launch argument standing in for a tap on a widget, so a UI test can drive the promise
    /// those surfaces make without a second app to open the URL from.
    static let focusCaptureArgument = "--focus-capture"

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "square.and.pencil", value: AppTab.newThought) {
                CaptureView(
                    model: CaptureModel(
                        repository: environment.thoughts,
                        intelligence: environment.intelligence,
                        changes: environment.changes,
                        clock: environment.clock
                    ),
                    habits: DailyHabitsModel(
                        repository: environment.thoughts,
                        changes: environment.changes,
                        clock: environment.clock
                    ),
                    changes: environment.changes,
                    focus: captureFocus
                )
            }

            Tab("Thoughts", systemImage: "tray.full", value: AppTab.thoughts) {
                thoughtsTab
            }

            Tab("Plan", systemImage: "checklist", value: AppTab.plan) {
                NavigationStack {
                    PlanView(model: plan, onOpen: { todo in
                        Task {
                            planOpened = try? await environment.thoughts.all().first { $0.id == todo.id }
                        }
                    }, onReview: {
                        reviewTasks = true
                        selection = .review
                    })
                    .navigationDestination(item: $planOpened) { thought in
                        ThoughtDetailView(
                            model: ThoughtDetailModel(
                                thought: thought, repository: environment.thoughts,
                                changes: environment.changes, clock: environment.clock
                            ),
                            onEnhance: { planSharpening = thought }
                        )
                    }
                    .navigationDestination(item: $planSharpening) { thought in
                        SharpenView(model: SharpenModel(
                            thought: thought, repository: environment.thoughts,
                            intelligence: environment.intelligence,
                            changes: environment.changes, clock: environment.clock
                        ))
                    }
                }
            }

            // Review is where the app's value is actually realised, so it is a place rather than
            // a link buried in the inbox's header (ADR-0040). Still never presented on launch and
            // still never blocking: it is a tab you choose, like any other.
            Tab("Review", systemImage: "checkmark.circle", value: AppTab.review) {
                NavigationStack {
                    review
                }
            }

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack {
                    settings
                }
            }
        }
        // Runs after the field is on screen, never before it.
        .task { await environment.prepare() }
        // A launch that came from a widget, Siri or Control Center goes through exactly the path
        // the URL takes, so the test drives the real mechanism rather than a parallel one.
        .task {
            guard ProcessInfo.processInfo.arguments.contains(Self.focusCaptureArgument) else {
                return
            }
            captureFocus.request()
        }
        // The ambient surfaces open `fleeting://capture` and promise a focused field. Handled
        // here rather than inside capture, because the request also has to select its tab.
        .onOpenURL(perform: openURL)
        .task {
            await plan.load()
            for await _ in environment.dailyChanges.changes {
                await plan.load()
                if environment.storageIsShared {
                    WidgetCenter.shared.reloadTimelines(ofKind: "FleetingDailyPlan")
                    WidgetCenter.shared.reloadTimelines(ofKind: "FleetingTomorrowPlan")
                    WidgetCenter.shared.reloadTimelines(ofKind: "FleetingFreshness")
                }
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await plan.load()
            // Sleep to the calendar boundary, including 23/25-hour daylight-saving days.
            while !Task.isCancelled {
                let now = environment.clock.now
                guard let midnight = Calendar.autoupdatingCurrent.dateInterval(of: .day, for: now)?.end
                else { return }
                do { try await Task.sleep(for: .seconds(max(1, midnight.timeIntervalSince(now)))) } catch {
                    return
                }
                await plan.load()
                WidgetCenter.shared.reloadTimelines(ofKind: "FleetingDailyPlan")
                WidgetCenter.shared.reloadTimelines(ofKind: "FleetingTomorrowPlan")
            }
        }
        .task {
            // Copy is written ahead of time, so the queue is rebuilt whenever the store might
            // have moved on. Never before the field is on screen.
            for await _ in environment.changes.changes {
                if environment.storageIsShared {
                    WidgetCenter.shared.reloadTimelines(ofKind: "FleetingFreshness")
                }
                await environment.refreshNudges()
            }
        }
    }
}

extension RootView {
    private func openURL(_ url: URL) {
        if url.scheme == "fleeting", url.host == "plan" {
            plan.showToday()
            if let day = requestedPlanDay(in: url) {
                plan.selectedDay = day
            }
            selection = .plan
            return
        }
        if url.scheme == "fleeting", url.host == "daily-review" {
            reviewTasks = true
            selection = .review
            return
        }
        guard CaptureFocus.isCaptureRequest(url) else { return }
        selection = .newThought
        captureFocus.request()
    }

    private func requestedPlanDay(in url: URL) -> PlanDay? {
        let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first(where: { $0.name == "day" })?.value
        guard let raw, let value = Int(raw), (10101 ... 99_991_231).contains(value) else { return nil }
        let day = PlanDay(rawValue: value)
        return day.date() == nil ? nil : day
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
                review
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

    /// The review session, reachable both as its own tab and as a push from the inbox's
    /// "N to decide" line, so the two entry points cannot drift apart.
    private var review: some View {
        VStack(spacing: 0) {
            Picker("Review", selection: $reviewTasks) {
                Text("Thoughts").tag(false)
                Text("Daily tasks (\(plan.pendingReview.count))").tag(true)
            }
            .pickerStyle(.segmented)
            .padding()
            if reviewTasks {
                DailyReviewView(model: plan)
            } else {
                thoughtReview
            }
        }
        .navigationTitle("Review")
        .background(Palette.surface.ignoresSafeArea())
    }

    private var thoughtReview: some View {
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

    /// The settings tab.
    private var settings: some View {
        SettingsView(
            model: SettingsModel(
                intelligence: environment.intelligence,
                sortingStore: environment.sortingPreference,
                decayStore: environment.decayProfiles,
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
