# Architecture

> **Purpose of this file.** It is the map of the codebase: every folder, what belongs in it, what is
> forbidden in it, and where to put a new thing. It is kept current as the app is built — if you are
> a future session picking this repo up, read this before opening any Swift file.
>
> **Last updated:** Phase 0 (Foundations) — structure defined, implementation in progress.

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
           Features                ← Capture, Inbox, Sharpen, Review, Archive, Settings
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
├── README.md                        ← product-facing overview (portfolio front door)
├── ARCHITECTURE.md                  ← you are here
├── CLAUDE.md                        ← working agreement for AI sessions
├── .swiftlint.yml                   ← incl. custom rules enforcing the Date() and cross-feature bans
├── .swiftformat
├── project.yml                      ← XcodeGen source of truth. The .xcodeproj, both Info.plists
│                                      and both .entitlements files are generated from it and
│                                      gitignored: one place declares the app's shape.
├── .github/workflows/ci.yml         ← build · test · lint on every push
│
├── docs/
│   ├── DECISIONS.md                 ← ADR log: every significant choice + alternatives
│   └── ROADMAP.md                   ← phases, scope, acceptance criteria
│
├── Fleeting.xcodeproj
│
├── App/                             ← THIN. Wiring, entry point, resources. No business logic.
│   ├── FleetingApp.swift            ← @main; builds the container, injects into the root view
│   ├── Composition/
│   │   ├── AppEnvironment.swift     ← the single place concrete types are chosen
│   │   └── IntelligenceFactory.swift← picks Foundation Models vs heuristics at runtime
│   ├── Intents/
│   │   └── CaptureThoughtIntent.swift ← Siri and Shortcuts capture without opening the app
│   ├── Navigation/
│   │   └── RootView.swift           ← capture is the root; everything else is a push or sheet
│   └── Resources/
│       ├── Assets.xcassets
│       └── Info.plist
│
├── Packages/
│   │
│   ├── Core/                        ← ZERO dependencies. Pure Swift. The heart of the app.
│   │   └── Sources/Core/
│   │       ├── Model/
│   │       │   ├── Thought.swift            ← the single domain entity
│   │       │   ├── ThoughtKind.swift        ← idea · todo · habit · unsorted
│   │       │   ├── ThoughtState.swift       ← inbox · active · snoozed · archived · done
│   │       │   ├── KindSource.swift          ← unclassified · inferred · confirmed
│   │       │   ├── ThoughtScope.swift        ← live · archived · all
│   │       │   └── Streak.swift             ← habit-specific payload
│   │       ├── Decay/
│   │       │   ├── Freshness.swift          ← 0…1 value type + presentation bands
│   │       │   ├── FreshnessPolicy.swift    ← grace + lifetime, linear decay (ADR-0013)
│   │       │   ├── DecayProfiles.swift      ← per-kind rates: todo 14d · habit 7d · idea 90d
│   │       │   └── DecayEngine.swift        ← pure: (Thought, Date) → Freshness
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
│   │       │   ├── ArchiveSweeping.swift    ← lets features trigger a sweep without Persistence
│   │       │   ├── IntelligenceService.swift← the AI contract, Classification, availability
│   │       │   ├── ThoughtChanges.swift     ← change signal so open screens see late work
│   │       │   └── SyncReporting.swift      ← is anything reaching iCloud? + a local-only stub
│   │       └── Support/
│   │           └── WallClock.swift          ← injected time; makes decay deterministic in tests
│   │
│   ├── Persistence/                 ← SwiftData + CloudKit. The only module that knows about storage.
│   │   └── Sources/Persistence/
│   │       ├── PersistenceError.swift    ← failures the store reports to the domain
│   │       ├── Schema/
│   │       │   ├── ThoughtEntity.swift      ← typealias naming the version in use; nothing else does
│   │       │   ├── ThoughtSchemaV1.swift    ← the store as Phase 6 shipped it; migration source
│   │       │   ├── ThoughtSchemaV2.swift    ← @Model in use; lifecycle values in single columns
│   │       │   ├── ThoughtMigrationPlan.swift ← custom v1 → v2 stage (ADR-0019)
│   │       │   └── StoredSharpening.swift   ← Codable DTO for the interview, stored as JSON
│   │       ├── Mapping/
│   │       │   ├── ThoughtEntity+Domain.swift ← entity ⇄ Core.Thought, both directions
│   │       │   ├── StoredState.swift        ← lifecycle ⇄ one merge-safe column
│   │       │   └── StoredStreak.swift       ← streak ⇄ one merge-safe column
│   │       ├── Repositories/
│   │       │   ├── SwiftDataThoughtRepository.swift
│   │       │   └── InMemoryThoughtRepository.swift  ← previews and tests; no store required
│   │       ├── Maintenance/
│   │       │   └── ArchiveSweeper.swift      ← runs the decay engine, archives what expired
│   │       ├── Sync/
│   │       │   └── CloudKitSyncReporter.swift ← asks CloudKit about the account, only if attached
│   │       └── Container/
│   │           ├── ModelContainerFactory.swift ← production, in-memory, and preview containers
│   │           ├── OpenedStore.swift        ← the container + what opening it gave up
│   │           └── CloudAttachment.swift    ← whether iCloud was attached, and why not
│   │
│   ├── Intelligence/                ← Everything AI. Swappable, testable, optional at runtime.
│   │   └── Sources/Intelligence/
│   │       ├── FoundationModels/
│   │       │   ├── FoundationModelsIntelligence.swift ← on-device LLM implementation
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
│   │   └── Sources/DesignSystem/
│   │       ├── Tokens/              ← Palette, Typography, Spacing, Motion, FreshnessStyle
│   │       │                          FreshnessStyle takes a Double, never a Thought (ADR-0012)
│   │       ├── Components/          ← domain-AGNOSTIC only (ADR-0012): parameterised by
│   │       │                          primitives, never by a Thought
│   │       └── Modifiers/
│   │
│   ├── Features/                    ← One target per feature. Features never import each other.
│   │   └── Sources/
│   │       ├── CaptureFeature/      ← the sacred path: launch → cursor → save → clear
│   │       │   ├── CaptureModel.swift   ← @Observable; the rules, unit-tested without a simulator
│   │       │   └── CaptureView.swift    ← the field, autofocused; save sits in a safeAreaInset
│   │       ├── InboxFeature/        ← the living list, sorted and faded by freshness
│   │       │   ├── InboxModel.swift     ← @Observable; load, revise, delete
│   │       │   ├── InboxView.swift      ← plain list; swipe to delete, tap to edit
│   │       │   ├── ThoughtRow.swift     ← lives here, not DesignSystem (ADR-0012)
│   │       │   └── ThoughtEditor.swift  ← edits raw text; commits only on save
│   │       ├── SharpenFeature/      ← interview → write-up → escalate
│   │       │   ├── SharpenModel.swift   ← phases; every answer persisted as it is given
│   │       │   └── SharpenView.swift    ← one question at a time; raw note always visible
│   │       ├── ReviewFeature/       ← the weekly capped card stack
│   │       ├── ArchiveFeature/      ← search the dead
│   │       │   ├── ArchiveModel.swift   ← scoped search, restore, permanent delete
│   │       │   └── ArchiveView.swift    ← .searchable over raw captured text
│   │       └── SettingsFeature/     ← honest intelligence status; the decay rates in force
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
│   ├── WidgetStore.swift            ← reads through the same repository the app uses
│   └── WidgetCompletion.swift       ← carries WidgetKit's completion across an await
│
└── Tests/                           ← ONLY cross-cutting tests. Unit tests live inside their own
    └── UITests/                        package (Packages/Core/Tests/CoreTests, and so on), so
        └── CapturePathTests.swift      `swift test` on one package runs its suite in isolation.
                                     ← CapturePathTests: launch → typing is unobstructed
                                       InboxTests: browse, edit, delete, survive a force-quit
                                       ArchiveTests: archive, restore, never destroy
                                       SyncTests: a store that cannot reach iCloud is still whole
                                       ScreenshotTests: regenerates README images
```

## 4. Where do I add…?

| I want to add… | Put it in | And also |
|---|---|---|
| A new field on a thought | `Core/Model/Thought.swift` | mirror it in `Persistence/Schema` + the mapping file, add a schema version |
| A new kind of thought | `Core/Model/ThoughtKind.swift` | give it a decay profile in `FreshnessPolicy`, a row treatment, a classifier case |
| A new screen | a new target under `Packages/Features/` | declare it in `Package.swift`; route it from `App/Navigation/RootView.swift` |
| A new AI capability | a method on `Core/Protocols/IntelligenceService.swift` | implement in **all three** of FoundationModels, Heuristic, Stub — no exceptions |
| A new colour or spacing value | `DesignSystem/Tokens/` | never a literal in a feature |
| A rule about when things expire | `Core/Decay/FreshnessPolicy.swift` | it's pure — cover it in `CoreTests` |
| A change to what the weekly review shows | `Core/Review/ReviewSelector.swift` | it's pure — cover it in `CoreTests` |
| Anything that touches the database | `Persistence/Repositories/` | expose it through the protocol in `Core`, never leak SwiftData types upward |
| A new stored column | `Persistence/Schema/ThoughtSchemaV*.swift` | add a version + a stage to `ThoughtMigrationPlan`; if it only means something paired with another column, store the pair as one value (ADR-0019) |

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
