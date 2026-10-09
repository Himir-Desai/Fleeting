# Architecture

> **Purpose of this file.** It is the map of the codebase: every folder, what belongs in it, what is
> forbidden in it, and where to put a new thing. It is kept current as the app is built — if you are
> a future session picking this repo up, read this before opening any Swift file.
>
> **Last updated:** iCloud list collaboration — the existing SwiftData model/store now opens
> through native Core Data sharing, with private personal activity (ADR-0069).

---

## 1. Shape of the project

Fleeting is an **app target that contains almost no code**, sitting on top of **local Swift packages**
that contain almost all of it. This is the central structural decision ([ADR-0002](docs/DECISIONS.md)),
and it buys three things:

1. **Compile-time enforced layering.** A feature can't reach into the database because its
   `Package.swift` doesn't declare the dependency. Architecture that can be violated by an `import`
   isn't architecture.
2. **Fast, framework-free domain tests.** `Core` builds and tests in seconds without a simulator.
3. **Navigable folders.** Every concept has exactly one obvious home, so finding a file is a
   sequence of confident folder clicks rather than a project-wide search.

## 2. Dependency rule

Dependencies point **downward only**. `Core` is the floor and imports nothing.

```
        App  ·  Widgets            ← composition roots, wiring only
              ↓
           Features                ← Capture, Inbox, Sharpen, Review, Settings
              ↓
  DesignSystem   Intelligence      ← presentation vocabulary · LLM abstraction
              ↓         ↓
     Persistence    Notifications  ← concrete implementations of Core's protocols
              ↓
             Core                  ← domain model, decay engine, protocols
```

Three rules, no exceptions:

- **`Core` imports nothing** — not SwiftUI, not SwiftData, not UIKit. If it needs the outside world,
  it declares a protocol and someone below implements it.
- **Features never import other Features.** Cross-feature communication goes through `Core` types or
  a coordinator in the app layer.
- **Only `App` and `Widgets` know about concrete types.** Everything else depends on protocols.

## 3. File map

This is the **target architecture**. Directories arrive with the phase that first needs them —
[docs/ROADMAP.md](docs/ROADMAP.md) is the record of what is built today. A file that exists must
appear here; a file here that does not yet exist is a commitment, not a lie.

```
Fleeting/
│
├── .agents/skills/apple-design/SKILL.md ← installed Apple interface/motion guidance
├── skills-lock.json                 ← source and hash of the requested skill
├── README.md                        ← product-facing overview (portfolio front door)
├── ARCHITECTURE.md                  ← you are here
├── CLAUDE.md                        ← working agreement for AI sessions
├── .swiftlint.yml                   ← incl. custom rules enforcing the Date() and cross-feature bans
├── .swiftformat
├── project.yml                      ← XcodeGen source of truth. The .xcodeproj, both Info.plists
│                                      and both .entitlements files are generated from it and
│                                      committed for Xcode Cloud; regenerate after editing the spec.
├── Tools/verify-distribution.py      ← validates signed IPA production sync/widget permissions before upload
├── .github/workflows/ci.yml         ← build · test · lint on every push
│
├── docs/
│   ├── DECISIONS.md                 ← ADR log: every significant choice + alternatives
│   ├── DESIGN_AUDIT.md             ← app-wide Apple-design findings, changes and visual verification
│   ├── screenshots/list-sheets/   ← first list-sheet revision, retained as history
│   ├── screenshots/navigation-revision/ ← historical custom navigation and espresso/lavender pass
│   ├── screenshots/native-bar/   ← prior native 3/4-tab revision, retained as history
│   ├── screenshots/permanent-native-tabs/ ← prior selector-preserves-page revision
│   ├── screenshots/list-destination-followup/ ← empty Lists, shared assignment, row type and circular close
│   ├── ROADMAP.md                   ← phases, scope, acceptance criteria
│   └── ICLOUD.md                    ← signing, production schema and two-device acceptance
│
├── Fleeting.xcodeproj                ← tracked project, shared Fleeting scheme, workspace and Cloud manifest
│
├── App/                             ← THIN. Wiring, entry point, resources. No business logic.
│   ├── FleetingApp.swift            ← @main; builds the container, injects into the root view
│   ├── Composition/
│   │   ├── AppEnvironment.swift     ← the single place concrete types are chosen
│   │   ├── DemoData.swift           ← DEBUG only: --seed-demo and --seed-many fixtures
│   │   └── IntelligenceFactory.swift← picks Foundation Models vs heuristics at runtime
│   ├── Intents/
│   │   └── CaptureThoughtIntent.swift ← Siri and Shortcuts capture without opening the app
│   ├── Navigation/
│   │   ├── AppTab.swift             ← Home · Thoughts · Lists · Plan native tab identities
│   │   ├── NativeListChoices.swift  ← domain adapter for shared list-choice rows
│   │   └── RootView.swift           ← tab content and sheet routing; shared keyboard observation
│   ├── Sharing/
│   │   ├── DevelopmentCloudSchema.swift ← explicitly requested DEBUG-only schema initialization
│   │   ├── ListSharingCoordinator.swift ← native invitations/management; exact-list routing after import
│   │   └── ShareInvitationHandler.swift ← cold/warm scene delegates and pending invitation queue
│   └── Resources/
│       ├── Assets.xcassets/         ← the app icon; generated, see docs/ASSETS.md
│       └── PrivacyInfo.xcprivacy    ← nothing collected, nothing tracked (docs/PRIVACY.md)
│                                      Info.plist and the entitlements sit at App/ and are
│                                      generated by XcodeGen and checked in for remote builds
│
├── Packages/
│   │
│   ├── Core/                        ← ZERO dependencies. Pure Swift. The heart of the app.
│   │   └── Sources/Core/
│   │       ├── Model/
│   │       │   ├── Thought.swift            ← captured content with optional collection membership
│   │       │   ├── ThoughtList.swift        ← named collection, description, capture default; stable Plan identity
│   │       │   ├── ListSharing.swift        ← owner/editor/viewer access, without CloudKit dependencies
│   │       │   ├── ThoughtKind.swift        ← idea · todo · habit · unsorted
│   │       │   ├── ExpirationUnit.swift      ← days · weeks · months; a hand-set lifetime's unit
│   │       │   ├── ThoughtState.swift       ← inbox · active · snoozed · archived · done; isLive vs isAwake(at:)
│   │       │   ├── KindSource.swift          ← unclassified · inferred · confirmed
│   │       │   ├── ThoughtScope.swift        ← live · archived · all; a storage question (ADR-0033)
│   │       │   ├── KindGlyph.swift           ← the symbol, label and plural for each kind (ADR-0012)
│   │       │   ├── SortingPreference.swift   ← automatic · rules only; the choice (ADR-0030)
│   │       │   ├── Streak.swift             ← habit-specific payload; a run in cadence periods
│   │       │   └── HabitCadence.swift        ← daily…monthly: when due, run unit, decay (ADR-0048)
│   │       ├── Decay/
│   │       │   ├── Freshness.swift          ← 0…1 value type + presentation bands
│   │       │   ├── FreshnessPolicy.swift    ← grace + lifetime, linear decay (ADR-0013)
│   │       │   ├── DecayProfiles.swift      ← per-kind rates: todo 14d · habit 7d · idea 90d
│   │       │   ├── DecayEngine.swift        ← pure: (Thought, Date) → Freshness; a habit outlives its cadence
│   │       │   ├── UrgencyBand.swift        ← going soon · this month · plenty of time (ADR-0036)
│   │       │   └── DecayProfilesStoring.swift ← where the editable rates live (ADR-0031)
│   │       ├── Sharpen/
│   │       │   ├── Sharpening.swift         ← the interview: questions, answers, write-up
│   │       │   ├── SharpenQuestion.swift    ← one question + its answer; AnsweredQuestion
│   │       │   ├── WriteUp.swift            ← a title and a paragraph (ADR-0016)
│   │       │   └── Thought+Sharpening.swift ← begin, answer, attach, revert
│   │       ├── Nudge/
│   │       │   ├── NudgeSelector.swift      ← pure: what is worth surfacing, and what expires soon
│   │       │   ├── NudgePreferences.swift   ← when the app may speak + its storage contract
│   │       │   └── NudgeAuthorization.swift ← permission state + the asking contract
│   │       ├── Sync/
│   │       │   └── SyncStatus.swift         ← syncing, signed out, or local-only and why
│   │       ├── Review/
│   │       │   └── ReviewSelector.swift     ← pure: [Thought] → at most 7 needing a decision
│   │       │                                 eligibility and urgency rules (ADR-0017)
│   │       ├── Protocols/
│   │       │   ├── ThoughtRepository.swift  ← implemented by Persistence; scoped + searchable
│   │       │   ├── ThoughtListRepository.swift ← list CRUD; deletion retains all thoughts
│   │       │   ├── ListSharingService.swift ← system sharing presentation contract and user-facing failures
│   │       │   ├── ArchiveSweeping.swift    ← lets features trigger a sweep without Persistence
│   │       │   ├── IntelligenceService.swift← the AI contract, Classification, availability
│   │       │   ├── ThoughtChanges.swift     ← change signal so open screens see late work
│   │       │   └── SyncReporting.swift      ← is anything reaching iCloud? + a local-only stub
│   │       └── Support/
│   │           └── WallClock.swift          ← injected time; makes decay deterministic in tests
│   │
│   ├── Persistence/                 ← Core Data + CloudKit over the versioned SwiftData model/store.
│   │   └── Sources/Persistence/
│   │       ├── PersistenceError.swift    ← failures the store reports to the domain
│   │       ├── Schema/
│   │       │   ├── ThoughtEntity.swift      ← typealias naming the version in use (V8); nothing else does
│   │       │   ├── ThoughtSchemaV1.swift    ← the store as Phase 6 shipped it; migration source
│   │       │   ├── ThoughtSchemaV2.swift    ← lifecycle values in single columns
│   │       │   ├── ThoughtSchemaV3.swift    ← adds the per-thought lifetime column
│   │       │   ├── ThoughtSchemaV4.swift    ← migration source; adds a habit's cadence + its source
│   │       │   ├── ThoughtSchemaV5.swift    ← migration source; legacy checklist import table
│   │       │   ├── ThoughtSchemaV6.swift    ← named lists and optional listID on each thought
│   │       │   ├── ThoughtSchemaV7.swift    ← list descriptions and default thought types
│   │       │   ├── ThoughtSchemaV8.swift    ← optional list graph, share marker and private member activity
│   │       │   ├── ThoughtMigrationPlan.swift ← custom v1→v2 (ADR-0019); lightweight v2→v3, v3→v4
│   │       │   └── StoredSharpening.swift   ← Codable DTO for the interview, stored as JSON
│   │       ├── Mapping/
│   │       │   ├── ThoughtEntity+Domain.swift ← entity ⇄ Core.Thought, both directions
│   │       │   ├── StoredState.swift        ← lifecycle ⇄ one merge-safe column
│   │       │   └── StoredStreak.swift       ← streak ⇄ one merge-safe column
│   │       ├── Repositories/
│   │       │   ├── SwiftDataThoughtRepository.swift ← schema/migration compatibility and test fixtures
│   │       │   ├── ThoughtListTaskRepository.swift ← dated-task projection of any list
│   │       │   └── InMemoryThoughtRepository.swift  ← previews and tests; no store required
│   │       ├── Sharing/
│   │       │   ├── CollaborationModel.swift ← public SwiftData→Core Data model bridge; exact entity hashes
│   │       │   ├── CollaborationStore.swift ← private/shared scopes, pre-upgrade recovery, durable fallback
│   │       │   ├── CollaborationRepository.swift ← unified CRUD and legacy checklist import
│   │       │   ├── CollaborationLists.swift ← metadata, naming and protected shared-list deletion
│   │       │   ├── CollaborationAccess.swift ← fetched rows and native CloudKit permission checks
│   │       │   ├── CollaborationActivity.swift ← per-member private activity and common-content projection
│   │       │   ├── CollaborationMapping.swift ← complete thought mapping, including rollback columns
│   │       │   ├── CollaborationSharing.swift ← CKShare graph creation, acceptance and exact-list lookup
│   │       │   └── CollaborationPreview.swift ← DEBUG-only unsigned shared-store UI preview
│   │       ├── Maintenance/
│   │       │   └── ArchiveSweeper.swift      ← runs the decay engine, archives what expired
│   │       ├── Sync/
│   │       │   ├── CloudStoreChanges.swift  ← cloud imports / cross-process writes → feature notifier
│   │       │   └── CloudKitSyncReporter.swift ← asks CloudKit about the account, only if attached
│   │       ├── Preferences/
│   │       │   ├── CloudPreferences.swift  ← iCloud key-value bridge for user preferences
│   │       │   ├── UserDefaultsSortingPreference.swift ← the sorting choice
│   │       │   ├── UserDefaultsDecayProfiles.swift     ← the rates, as JSON in defaults
│   │       │   └── DecayProfilesCache.swift            ← the rates in force, read from any thread
│   │       └── Container/
│   │           ├── LocalStoreMigration.swift ← one-time local→App Group import, preserves source
│   │           ├── ModelContainerFactory.swift ← production, in-memory, and preview containers
│   │           ├── OpenedStore.swift        ← the container + what opening it gave up
│   │           └── CloudAttachment.swift    ← whether iCloud was attached, and why not
│   │       └── (Tests: PersistenceTests, and SchemaMigrationTests as a SEPARATE target — it
│   │           opens old-version containers, and SwiftData binds an entity name to one class
│   │           per process, so it must run as its own `swift test` invocation)
│   │
│   ├── Intelligence/                ← Everything AI. Swappable, testable, optional at runtime.
│   │   └── Sources/Intelligence/
│   │       ├── FoundationModels/
│   │       │   ├── FoundationModelsIntelligence.swift ← on-device LLM implementation
│   │       │   ├── GeneratedNudge.swift      ← structured reminder output
│   │       │   ├── OnDeviceGeneration.swift   ← capability checks, token budget, iOS 27 request options
│   │       │   ├── Generable/                ← @Generable structured-output types
│   │       │   │   ├── GeneratedClassification.swift
│   │       │   │   ├── GeneratedQuestions.swift
│   │       │   │   └── GeneratedWriteUp.swift
│   │       │   └── Availability.swift        ← is Apple Intelligence usable on this device?
│   │       ├── Heuristic/
│   │       │   └── HeuristicIntelligence.swift ← deterministic fallback; ships on every device
│   │       ├── Stub/
│   │       │   └── StubIntelligence.swift    ← previews and tests
│   │       ├── Prompts/
│   │       │   ├── ClassificationPrompt.swift
│   │       │   ├── InterviewPrompt.swift     ← the 2–3 question Sharpen interview
│   │       │   ├── WriteUpPrompt.swift
│   │       │   ├── NudgePrompt.swift         ← daily "you forgot about this" copy
│   │       │   └── EscalationPrompt.swift    ← composes the prompt handed to Claude/ChatGPT
│   │       ├── Fallback/
│   │       │   └── ResilientIntelligence.swift ← tries on-device, degrades to heuristic on failure
│   │       └── IntelligenceAvailability.swift  ← which implementation is answering, and why
│   │
│   ├── DesignSystem/                ← The app's visual vocabulary. No business logic.
│   │   ├── Sources/DesignSystem/
│   │   │   ├── Tokens/
│   │   │   │   ├── RGB.swift            ← sRGB components + WCAG luminance, so contrast is testable
│   │   │   │   ├── ThemedColor.swift    ← one entry in light/dark × standard/increased contrast
│   │   │   │   ├── Palette.swift        ← the colour vocabulary; paper and ink (ADR-0022).
│   │   │   │   │                          three surfaces (page · well · card), accent (fill) vs
│   │   │   │   │                          accentText, and one separator instead of three literals
│   │   │   │   ├── Typography.swift     ← eleven styles, every one on a Dynamic Type text style;
│   │   │   │   │                          the serif is the user's voice, sans is the app's (ADR-0037)
│   │   │   │   ├── Spacing.swift        ← the layout steps; features never use raw numbers
│   │   │   │   ├── Radius.swift         ← control · card · well; the app's roundness, once
│   │   │   │   ├── Elevation.swift      ← a level, not a shadow: dark mode gets a hairline instead
│   │   │   │   ├── Motion.swift         ← timings by intent; applied only via .motion (ADR-0020)
│   │   │   │   │                          decay · commit · card · growth
│   │   │   │   └── FreshnessStyle.swift ← takes a Double, never a Thought (ADR-0012). the fade,
│   │   │   │                              the rail, and the card's sink + elevation (ADR-0035)
│   │   │   ├── Components/          ← domain-AGNOSTIC only (ADR-0012): parameterised by
│   │   │   │   ├── FreshnessMeter.swift  primitives, never by a Thought
│   │   │   │   ├── CardSurface.swift    ← a card's ground, sinking with freshness (ADR-0035)
│   │   │   │   ├── SproutMark.swift     ← a stem and two leaves, drawn by trim (ADR-0042)
│   │   │   │   ├── GrowingSprout.swift  ← the mark, growing itself once on appear (ADR-0042)
│   │   │   │   ├── VineRule.swift       ← a stem of leaves; a thing that has grown a while
│   │   │   │   ├── GrowthProgress.swift ← a vine that gains a leaf per decision (ADR-0045)
│   │   │   │   ├── ClimbingVine.swift   ← page texture for the capture screen (ADR-0046)
│   │   │   │   ├── Card.swift           ← content on a card, for cards outside a List
│   │   │   │   ├── GlassListPicker.swift ← native capture list menu and compact text label
│   │   │   │   ├── ListSelectionChoices.swift ← shared navigation/assignment popover rows and management actions
│   │   │   │   ├── RoundIconButton.swift ← shared type choices and round actions
│   │   │   │   ├── KeyboardDismissButton.swift ← shared glass keyboard-down icon
│   │   │   │   ├── ReviewAction.swift ← shared capsule decision for thought/task review
│   │   │   │   ├── ReviewActionRow.swift ← one adaptive set of review decisions
│   │   │   │   ├── PressFeedbackStyle.swift ← immediate feedback on custom controls
│   │   │   │   ├── ToolbarPill.swift  ← balanced glass action groups and floating control treatment
│   │   │   │   ├── StatusBlock.swift    ← an answer and its explanation; every Settings row
│   │   │   │   ├── SectionLabel.swift   ← a section's name, small and wide
│   │   │   │   └── EmptyState.swift     ← what a screen says when it has nothing to show
│   │   │   └── Modifiers/
│   │   │       ├── PageHeading.swift ← left-aligned headings including selected list titles
│   │   │       ├── KeyboardVisibility.swift ← live keyboard state per page/modal presentation
│   │   │       ├── KeyboardDismissControl.swift ← focused-field accessory for all editing flows
│   │   │       ├── MotionModifier.swift ← the one place animation is applied; honours Reduce Motion
│   │   │       └── ElevationModifier.swift ← the one place elevation is drawn; shadow or hairline
│   │   └── Tests/DesignSystemTests/
│   │       └── PaletteContrastTests.swift ← the contrast audit; fails the build, not an opinion
│   │
│   ├── Features/                    ← One target per feature. Features never import each other.
│   │   └── Sources/
│   │       ├── CaptureFeature/      ← home: the field, today's habits, save → clear
│   │       │   ├── CaptureModel.swift   ← @Observable; the rules, unit-tested without a simulator
│   │       │   ├── CaptureView.swift    ← a full-bleed page; save rides the keyboard (ADR-0039)
│   │       │   ├── CaptureViewPreview.swift ← the preview and its do-nothing collaborators
│   │       │   ├── CaptureReceipt.swift ← what a save filed: words · kind · lifetime (ADR-0038)
│   │       │   ├── CaptureReceiptCard.swift ← the card the saved text collapses into (ADR-0038)
│   │       │   ├── CaptureFocus.swift    ← the ambient surfaces' request for the cursor (ADR-0047)
│   │       │   ├── DailyHabitsModel.swift ← @Observable; today's habits, due first (ADR-0047)
│   │       │   ├── HabitStrip.swift      ← the vertical stack of due habits (ADR-0047, ADR-0048)
│   │       │   ├── HabitCard.swift       ← one habit: words, cadence · streak, one tap to keep
│   │       │   └── FirstRunHint.swift    ← the one-line explanation of decay (ADR-0021)
│   │       ├── InboxFeature/        ← the living list: urgency sections, sinking cards, detail
│   │       │   ├── InboxModel.swift     ← @Observable; load, urgency sections, counts, row actions
│   │       │   ├── ThoughtListsView.swift ← single list in a sheet; stacked create/edit forms
│   │       │   ├── ThoughtListEditorView.swift ← shared name, description and default-type form
│   │       │   ├── ThoughtListSharingControls.swift ← native sharing action and grouped explanation
│   │       │   ├── ThoughtKindPicker.swift ← same four round icons for thoughts and list defaults
│   │       │   ├── InboxView.swift      ← masthead + urgency sections; kind is a menu (ADR-0036)
│   │       │   ├── InboxFilter.swift    ← all · kind · archived; the menu selection
│   │       │   ├── InboxListRow.swift   ← a live row: kind glyph, tap-to-open, inline done/streak
│   │       │   ├── ArchivedListRow.swift ← an archived row: words + captured date, restore/delete
│   │       │   ├── ThoughtRow.swift     ← the thought's words in the serif (ADR-0037); ADR-0012
│   │       │   ├── ThoughtDetailModel.swift ← @Observable; edit · retype · keep · snooze · archive · delete
│   │       │   ├── ThoughtDetailView.swift  ← the opened thought: the action hub (ADR-0027)
│   │       │   ├── KindActionButton.swift   ← mark done · continue streak; sprout for a habit
│   │       │   ├── CadenceSection.swift   ← how often a habit is kept, and the picker (ADR-0048)
│   │       │   ├── StreakSection.swift      ← the streak's vine, and Undo (ADR-0044)
│   │       │   └── ExpiryWheels.swift   ← number + unit wheels; the only copy now (ADR-0039)
│   │       ├── SharpenFeature/      ← interview → write-up → escalate
│   │       │   ├── SharpenModel.swift   ← phases; every answer persisted as it is given
│   │       │   └── SharpenView.swift    ← one question at a time; raw note always visible
│   │       ├── ReviewFeature/       ← the weekly capped card stack
│   │       └── SettingsFeature/     ← where behaviour is changed (ADR-0032)
│   │           ├── SettingsModel.swift  ← @Observable; the choice, the switches, the rates
│   │           ├── SettingsView.swift   ← a card per section; About holds what cannot be set
│   │           ├── ChoiceChip.swift     ← one option in a small set, filled when chosen
│   │           ├── SettingsToggle.swift ← a switch with a line saying what it does
│   │           └── SettingsStepperRow.swift ← a value with a minus and a plus
│   │
│   └── Notifications/               ← Scheduling and background composition of nudges.
│       └── Sources/Notifications/
│           ├── NudgeKind.swift                ← the three permitted notifications (ADR-0009)
│           ├── NudgeIdentifier.swift          ← the identifiers this app owns, and only those
│           ├── NudgeClock.swift               ← next daily / weekly occurrence, calendar injected
│           ├── ScheduledNudge.swift           ← a delivery with its copy already written
│           ├── NudgeComposer.swift            ← writes the copy for each kind
│           ├── NudgeScheduler.swift           ← rebuilds the queue; cancels what is no longer wanted
│           ├── NudgeHistory.swift             ← what was surfaced recently, so it is not repeated
│           ├── UserDefaultsNudgePreferences.swift
│           └── SystemNotificationCentre.swift ← the real UNUserNotificationCenter, and permission
│
├── Widgets/                         ← Widget extension. Reads the shared store via Persistence.
│   ├── FleetingWidgetBundle.swift   ← @main; the extension's entry point
│   ├── FreshnessWidget.swift        ← live count + the thought fading fastest
│   ├── CaptureWidget.swift          ← lock screen; opens straight to a blank note
│   ├── CaptureControl.swift         ← Control Center button onto the same field
│   ├── OpenCaptureIntent.swift      ← what that button runs; opens the app and nothing else
│   ├── WidgetStore.swift            ← reads through the same repository the app uses
│   └── WidgetCompletion.swift       ← carries WidgetKit's completion across an await
│
├── Tools/
│   └── MakeIcon.swift               ← renders the app icon from the palette (docs/ASSETS.md)
│
└── Tests/                           ← ONLY cross-cutting tests. Unit tests live inside their own
    └── UITests/                        package (Packages/Core/Tests/CoreTests, and so on), so
        ├── CapturePathTests.swift      `swift test` on one package runs its suite in isolation.
        ├── ListFollowupTests.swift ← empty Lists destination, cleared ticks, shared assignment and editor chrome
        ├── NativeNavigationTests.swift ← four permanent tabs, destination selection and repeatable popover
        ├── InputControlsTests.swift ← keyboard dismissal in Plan, detail, review and sharpening
        └── TabNavigation.swift      ← the one place tests know how the tabs are reached
                                     ← CapturePathTests: launch → typing is unobstructed; habits on home (ADR-0047)
                                       InboxTests: browse, edit, delete, survive a force-quit
                                       ArchiveTests: archive, restore, never destroy
                                       SnoozeTests: a snooze survives a relaunch (ADR-0033)
                                       SyncTests: a store that cannot reach iCloud is still whole
                                       AccessibilityTests: operable at the largest type size
                                       FirstRunTests: the explanation blocks nothing and never returns
                                       PerformanceTests: cold launch to a usable field, budgeted
                                       ScreenshotTests: regenerates README images
```

## 4. Where do I add…?

Daily plan additions (ADR-0053), with paths relative to the repository root:

- `Packages/Core/Sources/Core/Model/PlanDay.swift` stores a civil date independent of time zones.
- `Packages/Core/Sources/Core/Model/DailyTodo.swift` defines the checklist projection and explicit review decisions.
- `Packages/Core/Sources/Core/Protocols/DailyTodoRepository.swift` defines checklist storage operations.
- `Packages/Persistence/Sources/Persistence/Repositories/ThoughtListTaskRepository.swift` projects
  dated tasks from any selected list; Plan and widgets use the built-in Plan ID.
  `CollaborationRepository.swift` owns thought storage and legacy checklist import; list operations
  and permission/activity helpers are split into its Sharing-folder extensions.
  `InMemoryThoughtRepository.swift` implements the same contracts; `InMemoryDailyTodoRepository.swift`
  remains a feature-test fixture. The separate SwiftData checklist actor has been removed.
- `Packages/Features/Sources/PlanFeature/PlanModel.swift` coordinates the week, tasks and overdue queue.
  `PlanView.swift` is the page, `PlanWeekPicker.swift` the seven buttons, `PlanTodoRow.swift` the checkbox,
  `PlanTaskText.swift` the animated multiline strike-through, and `DailyReviewView.swift` the decisions.
- `App/Composition/PlanDemoData.swift` supplies DEBUG-only `--seed-plan` fixtures.
- `Widgets/DailyPlanProvider.swift` projects today/tomorrow and midnight entries. `DailyPlanWidget.swift`
  declares both widgets; `CompleteDailyTodoIntent.swift` marks a task done idempotently.
- `Packages/Core/Tests/CoreTests/DailyTodoTests.swift`,
  `Packages/Features/Tests/PlanFeatureTests/PlanModelTests.swift`,
  `Packages/Persistence/Tests/PersistenceTests/DailyTodoRepositoryTests.swift`, and
  `Tests/UITests/PlanTests.swift` cover lifecycle, failed writes, widget/app consistency and UI.

`RootView` orders Home → Thoughts → Plan → Review → Settings. It owns one `PlanModel` for the page
and the Daily tasks segment of Review, refreshes on foreground/midnight, and handles `fleeting://plan`
(optional `day=YYYYMMDD`) and `fleeting://daily-review`. Plan and Thoughts share one change notifier and reload the checklist and freshness widgets.
`AppEnvironment` injects the checklist adapter over the same thought store.

| I want to add… | Put it in | And also |
|---|---|---|
| A new field on a thought | `Core/Model/Thought.swift` | mirror it in `Persistence/Schema` + the mapping file, add a schema version |
| A new kind of thought | `Core/Model/ThoughtKind.swift` | give it a decay profile in `FreshnessPolicy`, a row treatment, a classifier case; it gains a Settings stepper for free |
| A new user preference | a type in `Core` + a store in `Persistence/Preferences` | Settings owns the control; read it live if it must apply without a relaunch (ADR-0030) |
| A new screen | a new target under `Packages/Features/` | declare it in `Package.swift`; route it from `App/Navigation/RootView.swift` |
| A new AI capability | a method on `Core/Protocols/IntelligenceService.swift` | implement in **all three** of FoundationModels, Heuristic, Stub — no exceptions |
| A new colour or spacing value | `DesignSystem/Tokens/` | never a literal in a feature; a new colour needs a pairing in `PaletteContrastTests` |
| A view two screens both need | `DesignSystem/Components/` | only if it can be parameterised by primitives (ADR-0012); if it needs a `Thought`, it belongs to the feature |
| A rule about when things expire | `Core/Decay/FreshnessPolicy.swift` | it's pure — cover it in `CoreTests` |
| A change to what the weekly review shows | `Core/Review/ReviewSelector.swift` | it's pure — cover it in `CoreTests` |
| Anything that touches the database | `Persistence/Repositories/` | expose it through the protocol in `Core`, never leak SwiftData types upward |
| A new stored column | `Persistence/Schema/ThoughtSchemaV*.swift` | add a version + a stage to `ThoughtMigrationPlan`; if it only means something paired with another column, store the pair as one value (ADR-0019); test it in `SchemaMigrationTests`, which runs in its own process |

## 5. Conventions

**Concurrency.** Swift 6 strict concurrency, complete checking. Domain types are `Sendable` value
types. Persistence is actor-isolated; features are `@MainActor`. No `@unchecked Sendable` without a
comment justifying it.

**State.** Features use `@Observable` state models (Observation framework), constructed with their
dependencies as protocols. Views hold no business logic and read no globals — everything arrives
through the initialiser or the environment.

**Time.** Nothing calls `Date()` anywhere but `SystemClock`. Anything time-dependent takes
a `WallClock` from `Core/Support`. This is what makes the decay engine testable in milliseconds.

**Intelligence is always optional.** Every call into `IntelligenceService` must have a defined
behaviour when the model is unavailable, slow, or wrong. `ResilientIntelligence` handles the
degradation centrally; features must never check device capability themselves.

**Naming.** Files are named for the single type they contain. Protocols read as capabilities
(`ThoughtRepository`), implementations name their strategy (`SwiftDataThoughtRepository`).

**Documentation.** Public types and functions carry Javadoc-style `///` doc comments stating **what**
they do, with `- Parameter` and `- Returns` where the signature isn't self-evident — enough for a new
developer to use the API without reading the body. Design rationale belongs in
[docs/DECISIONS.md](docs/DECISIONS.md), never in a comment. Prompts document their expected output
shape.

## 6. Invariants worth protecting

`Packages/Intelligence/Tests/IntelligenceTests/GeneratedOutputTests.swift` covers generated-output
validation: invalid confidence, non-habit cadence, duplicate questions, and empty write-ups.

These are the things that, if broken, mean the app has become the thing it was built to replace:

1. **Nothing blocks the capture field.** No sheet, alert, permission prompt, onboarding, or "what's
   new" may appear before the user can type on a cold launch. There is a UI test for this.
2. **Raw captured text is never mutated by the model.** Generated titles and write-ups live in
   separate fields. What you typed at 1am stays exactly as you typed it.
3. **Nothing is destroyed by decay.** Expiry moves a thought to the archive; deletion is only ever an
   explicit human act.
4. **Freshness resets on action, not on attention.** Scrolling past a thought must not keep it alive —
   that is precisely the failure mode of every other app.
5. **Capture is at most one tap away from any screen.** ADR-0008 protects the cold launch; this
   protects every moment after it. A screen reachable from capture must offer a *visible* control
   back to it — a swipe-down that works but cannot be seen does not count. There is a UI test.
6. **Values that only mean something together are stored together.** iCloud merges a record column
   by column, so a lifecycle position and its date in separate columns can arrive from two different
   devices and describe a state neither was ever in. `CloudMergeTests` demonstrates the tear on the
   old shape and its absence on the new one (ADR-0019).
7. **Setting a thought aside means it stays aside.** A snooze must survive a reload and must not be
   visible on any surface until it lapses. `ThoughtScope.live` is a *storage* answer and still
   contains running snoozes, because the store writes `isLive` at save time and cannot know when a
   snooze expires; anything showing thoughts to a person filters with `Thought.isAwake(at:)`
   (ADR-0033). The regression test asserts a **reload**, not just the in-memory removal.

### 2.0 iCloud regression coverage

- `Packages/Persistence/Tests/PersistenceTests/CloudPreferencesTests.swift`: local preference
  migration, remote precedence/removal, no echo writes, decay-cache invalidation.
- `Packages/Persistence/Tests/PersistenceTests/LocalStoreMigrationTests.swift`: local→App Group
  import preserves both stores, retains the original file, and does not resurrect deletions.
- `Packages/Features/Tests/InboxFeatureTests/CloudDetailTests.swift`: cloud edits refresh stored
  state while preserving drafts; remote deletion closes the detail.
- `ReviewModelTests.swift` also covers removing remotely deleted pending cards without resetting tally.

### Thought lists

Capture and Inbox use `DesignSystem/Components/GlassListPicker.swift` for the same native Menu
as the thought-kind filter. The system chooses its direction and handles outside-tap dismissal.
The compact text label truncates long names. `InboxFeature/ThoughtListsView.swift` presents the
manager as a native sheet; `ThoughtListEditorView.swift` supplies shared creation and editing.
Thought detail can change membership. Built-in Plan cannot be edited or deleted.

`ThoughtSchemaV6.swift` adds list records and `listID`; V5→V6 assigns existing to-dos to Plan
without changing their identities, dates, completion, or text. Lists share the thought CloudKit
container and notifier. Local→App Group import copies lists as well as thought membership.
`ThoughtListRepositoryTests.swift`, `InboxListTests.swift`, capture tests, migration tests, and
`Tests/UITests/ListTests.swift` cover list lifecycle, filtering, Plan membership and draft retention.

### App-wide design audit

`docs/DESIGN_AUDIT.md` records the Apple-design review of all destinations. Shared changes live in
Typography, Palette, Motion, PageHeading, PressFeedbackStyle and floating-glass presentation.
`Tests/UITests/DesignAuditTests.swift` navigates every destination, records appearance snapshots,
and checks large-type layouts and review gestures. Review and detail failure tests ensure that
visual feedback follows successful persistence rather than merely a button tap.

`docs/screenshots/design-audit/{light,dark}/` stores the nine-destination comparison sets and
additional large-type examples. The app-tour screenshots are refreshed from the verified dark set.

### Native menus and explicit review actions

`GlassListPicker` uses the same native Menu/inline Picker combination as `InboxFilterMenu`.
The system owns expansion, dismissal, layout direction and accessibility motion. Custom popup
geometry, spring timing and the outside-tap overlay are removed. Create list opens a bottom
sheet; capture drafts and keyboard focus survive dismissal.

`ReviewThoughtCard.swift` and `ReviewDecisions.swift` render scrolling thought cards using the
same `ReviewAction`/`ReviewActionRow` primitives as daily task review. ReviewModel supports choosing
any pending card while preserving another card's draft answer. `ThoughtReviewTests.swift` checks
Archive, Hide for 7 days and Keep active behavior. Horizontal shortcuts remain; vertical gestures
scroll the card list. Neither review action deletes a record.

`ReviewFeature/HorizontalReviewGesture.swift` rejects vertical drags before recognition so the
scrolling review stays usable, and passes horizontal translation/velocity to the card. The shared
review action row uses one live set of controls, avoiding duplicate adaptive-button instances.

`docs/screenshots/native-review/` captures the native Home/Thoughts menus and scrolling review
in ordinary and large text sizes. The current `review.png` tour image uses this presentation.


### List management sheets and metadata

Settings and list management use native bottom sheets. The manager shows Plan and custom lists in
one section, with a separate Create list action. Plan has no disclosure, edit or delete action.
Custom-row details and creation present `ThoughtListEditorView` in a sheet above the manager.
The same editor serves Home/Thoughts creation and the selected-list heading’s direct edit action;
RootView coordinates these routes without cross-feature dependencies. Existing Card, SectionLabel,
Typography, Palette and native toolbar controls supply the visual language.

V7 adds defaulted list description and default-kind columns via a lightweight V6→V7 migration.
Both repositories and local-store import preserve them. A selected custom list’s default type
applies at capture unless explicitly overridden; Unsorted retains background type classification.
Descriptions are persisted as context for future automatic list routing; no routing or sharing
service is added in this change. Thoughts’ selected name is its page heading, with an edit action in the toolbar and its
description above the thoughts. List selection lives in the native Lists tab.


### Contextual Lists navigation and shared editing controls

Native TabView owns the bar and destination state. All four tabs are always visible. Thoughts
and Lists have distinct selected states, and the Lists tab anchors a native popover with
NativeListChoices. Tapping Lists selects its empty destination and opens the chooser. A selected
collection supplies the page heading; leaving Lists clears only the navigation selection.
Thoughts always shows the all-thoughts destination. This
replaces ADR-0065’s custom weighted bar (see ADR-0066).

`RoundIconButton` supplies the icon, selected fill, tap feedback, label and accessibility state.
`ThoughtKindPicker` reuses it in thought properties and list defaults. Delete list reuses the
round trash action. The sheet editor has only a leading cross and trailing Create/Save action.

`KeyboardDismissButton` provides the same 52-point glass control on all input screens.
`KeyboardDismissControl` observes keyboard state in the active presentation, so stacked sheets
receive their own live updates. Focus stays owned by each feature; hiding the keyboard preserves
all drafts. Capture retains its existing accessory arrangement while using the shared button.

The current dark palette uses near-black brown surfaces and muted sage accents, retaining warm
ivory content and taupe metadata. Light appearance remains unchanged. Contrast tests cover both
standard and increased contrast. ADR-0066 records the update from the earlier espresso/lavender.


### Native tab-bar revision (supersedes the custom navigation portion of ADR-0065)

`RootView` uses the system TabView bar directly. Home, Thoughts, Lists and Plan are always visible.
The system owns item padding, selected highlight, safe-area margins, Liquid Glass and bar layout.
The Lists tab anchors TabContent.popover containing NativeListChoices. Its selection binding
opens/reopens the chooser within Lists; choosing a row filters that destination. NativeListChoices
uses the shared DesignSystem choices without an All thoughts option. Creation/deletion in Lists
keeps its selected collection consistent; leaving Lists clears that navigation state. No custom bar, weighted layout, matched
capsule, contextual tab hiding or app-level navigation spring remains.

Dark surfaces now use near-black brown (#161311 page, #231E1A card, #0E0C0A input), with sage-green
controls and accents. Light values remain unchanged. Contrast tests cover all four appearances.


### Permanent native tabs (ADR-0067)

The native iPhone tab bar has no public grouped background spanning two independently highlighted
items. UITabGroup/TabSection describe hierarchy and sidebar sections. Keep the user’s four-tab
native fallback, with no contextual hiding/count-change animation. ADR-0068 supersedes the prior
chooser-preserves-page behavior: Lists now immediately owns the empty destination, popover and
selected collection. No custom bar is introduced.


### Lists destination and shared assignment menu (ADR-0068)

Lists immediately selects its native tab and opens the tab-anchored selector. InboxView’s list
scope draws an empty canvas when no navigation collection is chosen; its all-thoughts scope stays
separate. Leaving Lists clears only InboxModel.selectedListID, and selecting a list stays within
the Lists destination. There is no All thoughts row in the navigation popover.

ListSelectionChoices in DesignSystem renders collection rows, ticks, separators, Add List and
Edit Lists. NativeListChoices maps domain values for navigation; ThoughtDetailView uses the same
rows in its anchored popover with an explicit No list assignment option. The app coordinates
creation/management from thought properties. Creating a list there assigns it to the thought
through ThoughtDetailModel.moveToList, preserving its text/history and in-progress draft without
changing navigation filters. Editor creation can opt out of navigation selection.

List manager name text uses the existing title3 serif token with a four-point leading inset;
row min-height, vertical padding and section spacing remain unchanged. The close toolbar button
uses an icon-only Label and native circular button border shape.


## iCloud shared lists (ADR-0069)

The composition roots (App, widgets and intents) use CollaborationStore/CollaborationRepository.
The public NSManagedObjectModel.makeManagedObjectModel bridge opens the exact existing V8 schema
and original private SQLite file; SwiftData runs the versioned migration and releases its container
first. Store UUID and existing record identities are retained. A coordinated pre-upgrade snapshot
preserves SQLite journal data. Cloud attachment failure retries durable local storage before the
existing memory fallback. A separate shared SQLite store holds accepted participants' zones.

A list's optional inverse relationship contains only its own thought records, including history.
MemberActivityEntity has scalar IDs and no relationships, is always assigned to the private store,
and overlays streak/attention/hiding on shared content. Completion and archive state remain common.
DecayEngine skips automatic archiving for shared thoughts. Protected Plan has no share action.
Native permissions are enforced in storage as well as UI; without cloud attachment, imported lists
conservatively become view-only. Cross-share membership changes fail without modifying content.

Features receive ListSharingService; CloudKit/UIKit remain in App and Persistence. RootView installs
exact-list routing and observes delayed imports. The scene delegate handles both cold-launch and
running-scene metadata. CKSharingSupported is in project.yml and generated Info.plist. Apple's
UICloudSharingController owns invitation delivery, access options and participant management.

Validation map:
- CoreTests/DecayEngineTests: shared manual archiving for all roles.
- CaptureFeatureTests/CaptureModelTests: shared receipt and denied-write draft preservation.
- ReviewFeatureTests/ReviewModelTests: viewer archive/sharpening restrictions and personal decisions.
- PersistenceTests/CollaborationStoreTests.swift: exact-store compatibility, CRUD, private activity,
  permission enforcement, graph isolation, shared completion and durable offline reopening.
- PersistenceTests/CollaborationPermissionTests.swift: partial shared-zone imports, same-account
  personal-activity collisions, received-list name collisions and viewer metadata enforcement.
- SchemaMigrationTests/SchemaMigrationTests.swift: V7→V8 identity/content/history recovery.
- Tests/UITests/SharingTests.swift: sharing entry point, unavailable-iCloud capture/relaunch,
  disabled viewer edits and personal habit progress; unsigned preview is explicitly not cloud acceptance.
- docs/ICLOUD.md: production-schema deployment and signed cross-account/device acceptance.


Shared-list visual evidence lives in docs/screenshots/shared-lists/shared-list-largest-light.png;
DESIGN_AUDIT.md records native-control reuse, viewer affordances and the preview's limits.
