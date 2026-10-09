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
/// Four native tabs, with home selected on launch, so a
/// cold launch still lands on the capture field with nothing before it (ADR-0008). Home carries
/// today's habits under that field, because a habit is the one thing here that needs daily
/// attention (ADR-0047). This is also the only place that knows every feature exists, so it wires
/// what each tab reaches.
struct RootView: View {
    let environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @State private var capture: CaptureModel
    @State private var inbox: InboxModel
    @State private var editingList: ThoughtList?
    @State private var creatingList: ThoughtList?
    @State private var creatingFromCapture = false
    @State private var listCreationCompletion: ((ThoughtList) -> Void)?
    @State private var managingFromThought = false
    @State private var isEditingLists = false
    @State private var isChoosingList = false
    @State private var plan: PlanModel
    @State private var isReviewingTasks = false
    @State private var isShowingSettings = false
    @State private var planOpened: Thought?
    @State private var planSharpening: Thought?

    init(environment: AppEnvironment) {
        self.environment = environment
        _capture = State(initialValue: CaptureModel(
            repository: environment.thoughts, intelligence: environment.intelligence,
            changes: environment.changes, clock: environment.clock, listRepository: environment.lists
        ))
        _inbox = State(initialValue: InboxModel(
            repository: environment.thoughts, sweeper: environment.sweeper,
            engine: environment.engine, clock: environment.clock, listRepository: environment.lists
        ))
        _plan = State(initialValue: PlanModel(
            repository: environment.dailyTodos, changes: environment.dailyChanges, clock: environment.clock
        ))
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
        TabView(selection: Binding(get: { selection }, set: selectTab)) {
            Tab("Home", systemImage: "square.and.pencil", value: AppTab.newThought) {
                NavigationStack {
                    CaptureView(
                        model: capture,
                        habits: DailyHabitsModel(
                            repository: environment.thoughts,
                            changes: environment.changes,
                            clock: environment.clock
                        ),
                        changes: environment.changes,
                        focus: captureFocus,
                        onCreateList: {
                            listCreationCompletion = nil
                            creatingFromCapture = true
                            creatingList = ThoughtList(name: "")
                        }
                    )
                    .pageHeading("Home") {
                        ToolbarPill {
                            Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                                .accessibilityIdentifier("app.settings")
                        }
                    }
                }
            }

            Tab("Thoughts", systemImage: "tray.full", value: AppTab.thoughts) {
                thoughtsTab(isListDestination: false)
            }

            Tab("Lists", systemImage: "list.bullet", value: AppTab.lists) {
                thoughtsTab(isListDestination: true)
            }
            .popover(isPresented: $isChoosingList, arrowEdge: .bottom) {
                listChoices
                    .presentationCompactAdaptation(.popover)
            }

            Tab("Plan", systemImage: "checklist", value: AppTab.plan) {
                NavigationStack {
                    PlanView(model: plan, onOpen: { todo in
                        Task {
                            planOpened = try? await environment.thoughts.all().first { $0.id == todo.id }
                        }
                    }, onReview: {
                        isReviewingTasks = true
                    }, onSettings: { isShowingSettings = true })
                        .navigationDestination(isPresented: $isReviewingTasks) {
                            DailyReviewView(model: plan)
                                .pageHeading("Daily review")
                                .toolbar { settingsToolbar }
                        }
                        .navigationDestination(item: $planOpened) { thought in
                            ThoughtDetailView(
                                model: ThoughtDetailModel(
                                    thought: thought, repository: environment.thoughts,
                                    changes: environment.changes, clock: environment.clock,
                                    listRepository: environment.lists
                                ),
                                onEnhance: { planSharpening = thought },
                                onAddList: addListForThought,
                                onEditLists: manageListsForThought
                            )
                            .toolbar { settingsToolbar }
                        }
                        .navigationDestination(item: $planSharpening) { thought in
                            SharpenView(model: SharpenModel(
                                thought: thought, repository: environment.thoughts,
                                intelligence: environment.intelligence,
                                changes: environment.changes, clock: environment.clock
                            ))
                            .toolbar { settingsToolbar }
                        }
                }
            }
        }
        .tabBarMinimizeBehavior(.never)
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                settings
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isShowingSettings = false }
                                .accessibilityIdentifier("settings.done")
                        }
                    }
            }
        }
        .sheet(isPresented: $isEditingLists) {
            NavigationStack {
                ThoughtListsView(
                    model: inbox,
                    selectCreatedList: selection == .lists && !managingFromThought,
                    sharingService: environment.sharing,
                    onChange: { environment.changes.notify() }
                )
            }
        }
        .sheet(item: $editingList) { list in
            NavigationStack {
                ThoughtListEditorView(
                    list: list,
                    isNew: false,
                    model: inbox,
                    sharingService: environment.sharing,
                    onChange: { environment.changes.notify() }
                )
            }
        }
        .sheet(item: $creatingList, onDismiss: {
            if creatingFromCapture {
                captureFocus.request()
            }
            listCreationCompletion = nil
        }) { list in
            NavigationStack {
                ThoughtListEditorView(
                    list: list,
                    isNew: true,
                    model: inbox,
                    selectOnCreate: selection == .lists && listCreationCompletion == nil,
                    sharingService: environment.sharing,
                    onChange: { environment.changes.notify() },
                    onSaved: { saved in
                        if creatingFromCapture {
                            capture.selectedListID = saved.id
                        }
                        listCreationCompletion?(saved)
                    }
                )
            }
        }
        // Runs after the field is on screen, never before it.
        .task { await environment.prepare() }
        .task {
            environment.sharing?.onAccepted = { id in
                selection = .lists
                inbox.selectedListID = id
                showThoughtsRoot()
                Task { await inbox.load() }
                isChoosingList = id == nil
            }
            await environment.sharing?.observeAcceptedLists()
        }
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
            environment.sharing?.presentPendingError()
            environment.changes.notify()
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
        .trackKeyboardVisibility()
    }
}

extension RootView {
    private func selectTab(_ tab: AppTab) {
        if tab == .lists {
            if selection != .lists {
                inbox.selectedListID = nil; showThoughtsRoot()
            }
            selection = .lists
            isChoosingList = true
            Task { await inbox.load() }
            return
        }
        isChoosingList = false
        inbox.selectedListID = nil
        if tab == .thoughts {
            showThoughtsRoot()
        }
        selection = tab
    }

    private var listChoices: some View {
        NativeListChoices(lists: inbox.lists, selectedID: inbox.selectedListID, onSelect: { id in
            inbox.selectedListID = id
            isChoosingList = false
            selection = .lists
            showThoughtsRoot()
        }, onCreate: {
            isChoosingList = false
            creatingFromCapture = false
            listCreationCompletion = nil
            creatingList = ThoughtList(name: "")
        }, onEdit: {
            isChoosingList = false
            managingFromThought = false
            isEditingLists = true
        })
    }

    private func addListForThought(_ completion: @escaping (ThoughtList) -> Void) {
        creatingFromCapture = false
        listCreationCompletion = completion
        creatingList = ThoughtList(name: "")
    }

    private func manageListsForThought() {
        managingFromThought = true
        isEditingLists = true
    }

    private func showThoughtsRoot() {
        opened = nil
        sharpening = nil
        isReviewing = false
    }

    private func openURL(_ url: URL) {
        if url.scheme == "fleeting", url.host == "plan" {
            selectTab(.plan)
            plan.showToday()
            if let day = requestedPlanDay(in: url) {
                plan.selectedDay = day
            }
            selection = .plan
            return
        }
        if url.scheme == "fleeting", url.host == "daily-review" {
            selectTab(.plan)
            isReviewingTasks = true
            return
        }
        guard CaptureFocus.isCaptureRequest(url) else { return }
        selectTab(.newThought)
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
    private func thoughtsTab(isListDestination: Bool) -> some View {
        NavigationStack {
            InboxView(
                model: inbox,
                changes: environment.changes,
                storageIsDegraded: environment.storageIsDegraded,
                isListDestination: isListDestination,
                onReview: { isReviewing = true },
                onOpen: { opened = $0 },
                onSettings: { isShowingSettings = true },
                onEditList: { editingList = $0 }
            )
            .navigationDestination(item: $opened) { thought in
                ThoughtDetailView(
                    model: ThoughtDetailModel(
                        thought: thought,
                        repository: environment.thoughts,
                        changes: environment.changes,
                        clock: environment.clock,
                        listRepository: environment.lists
                    ),
                    onEnhance: { sharpening = thought },
                    onAddList: addListForThought,
                    onEditLists: manageListsForThought
                )
                .toolbar { settingsToolbar }
            }
            .navigationDestination(isPresented: $isReviewing) {
                thoughtReview
                    .toolbar { settingsToolbar }
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
                .toolbar { settingsToolbar }
            }
        }
    }

    /// Opens app settings without changing the selected tab or navigation path.
    private var settingsToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                .accessibilityIdentifier("app.settings")
        }
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

    /// Settings presented from any page.
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
            ),
            changes: environment.changes
        )
    }
}
