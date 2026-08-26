# Roadmap

Nine phases. Each one ends with something that **runs on a device and is worth using** — no phase is
pure plumbing, and no phase is a big-bang integration. Each lists its scope, what it explicitly does
*not* include, and the acceptance criteria that mean it's done.

Status legend: ⚪️ planned · 🟡 in progress · 🟢 done

---

## Phase 0 · Foundations 🟢

Set up the skeleton the whole app hangs off, so no later phase has to stop and do infrastructure.

**Scope**
- Rename repository and directory `Memos` → `Fleeting`; Xcode project, bundle ID, iOS 26 target.
- The six local packages with their dependency graph wired and enforced.
- `Core` domain types compiling: `Thought`, `ThoughtKind`, `ThoughtState`, `Clock`.
- DesignSystem token files (colour, type, spacing, motion) — values provisional, structure final.
- SwiftLint + SwiftFormat config; GitHub Actions CI running build, test, and lint.
- Documentation set: README, ARCHITECTURE, DECISIONS, ROADMAP, CLAUDE.md.

**Not in this phase.** Any feature behaviour. The app launches to a placeholder.

**Done when** — CI is green on a clean checkout; `swift test` passes in `Core` without a simulator;
attempting to import `Persistence` from a `Features` target fails to compile.

**Outcome.** All three met, and each was demonstrated rather than asserted:

- CI green on the first run, all three jobs, including the iOS app build
  ([run 32145278022](https://github.com/Himir-Desai/Fleeting/actions/runs/32145278022)).
- `swift test --package-path Packages/Core` — 10 tests in ~1ms, no simulator.
- Adding `import Persistence` to `CaptureFeature` failed with `no such module 'Persistence'`.
- Beyond the criteria, two of CLAUDE.md's hard rules became custom SwiftLint rules; a probe file
  containing `Date()` was rejected with the intended message.

Local note: this Mac's Xcode has no iOS platform installed, so `xcodebuild` finds no destination
here. CI proves it is a machine gap, not a project one.

---

## Phase 1 · Capture 🟢

The sacred path, and nothing else. If this phase is wrong, the app has no reason to exist.

**Scope**
- Cold launch → focused text field, keyboard already up, zero intermediate state.
- Save commits and clears in place; the field stays focused for the next thought. No navigation, no
  confirmation, no toast that steals focus.
- SwiftData store (local), `ThoughtEntity`, mapping layer, `SwiftDataThoughtRepository`.
- A deliberately plain reverse-chronological list, reachable by a swipe or a small affordance.
- Edit and delete a thought.

**Not in this phase.** Types, decay, AI, search, sync — a thought is just text and a timestamp.

**Done when** — the UI test asserting an unobstructed cold-launch capture path passes; thoughts
survive a force-quit; capture works in Low Power Mode and with a cold store.

**Outcome.** Met. 32 unit tests run in milliseconds with no simulator; 6 UI tests run on one.

- `CapturePathTests` — cold launch reaches a focused field with the keyboard up, with no alert or
  sheet before it. This is ADR-0008 in executable form.
- `InboxTests` — a captured thought appears in the inbox, can be edited and deleted, and survives
  `app.terminate()` followed by a relaunch against the existing store.
- A failed save keeps the user's text rather than clearing the field, and a storage fault degrades
  to an in-memory store instead of blocking launch.

Deferred from this phase: an inbox screenshot for the README. Phase 2 replaces the row's timestamp
with the freshness treatment, so any screenshot taken now would be stale within one phase.

---

## Phase 2 · Decay 🟢

Turn the list into something that prunes itself. This is the mechanic the app exists for.

**Scope**
- `Freshness`, `FreshnessPolicy`, `DecayEngine` in `Core` — pure, clock-injected, exhaustively tested.
- Freshness rendered in the list as a genuine visual fade, not a badge or a number.
- Freshness resets on **action** (edit, act-in-review), never on viewing or scrolling.
- `ArchiveSweeper` moves expired thoughts to the archive on launch and on background refresh.
- Archive browser with full-text search — decay must never feel like loss.
- Manual snooze and manual archive.

**Not in this phase.** Per-kind decay rates (everything decays uniformly until Phase 3 introduces
kinds).

**Done when** — decay behaviour is proven by advancing a fake clock across weeks in unit tests;
nothing is ever deleted; archived thoughts are findable in under three seconds.

**Outcome.** Met. 30 Core tests drive decay across simulated months without waiting; the sweeper
archives and never deletes; the archive is searchable from the inbox in two taps.

- Decay is linear with a grace period rather than a half-life ([ADR-0013](DECISIONS.md)), so a row
  can truthfully say "archives tomorrow" instead of estimating.
- Snooze holds a thought at full freshness until it ends, so setting something aside buys time.
- Freshness resets on action only. A test asserts that repeatedly reading a thought's freshness
  does not change it.
- Deletion remains reachable only through an explicit human swipe, in the inbox or the archive.
- Fixed after review: the inbox shipped with no visible way back to capture, reachable only by an
  undiscoverable swipe-down. Now an explicit *Capture* control, protected by invariant 5 in
  ARCHITECTURE.md and by `ReturnToCaptureTests`.

---

## Phase 3 · Classification 🟢

Teach the app to sort so the user never has to. First contact with the intelligence layer.

**Scope**
- `IntelligenceService` protocol; `HeuristicIntelligence` implemented **first** so the app is complete
  without a model.
- `FoundationModelsIntelligence` using `@Generable` guided generation for kind + title.
- `ResilientIntelligence` wrapper: availability detection, timeout, automatic degradation.
- Classification runs in the background *after* capture returns — never on the capture path.
- Per-kind decay profiles from ADR-0005; one-tap kind correction in the list.
- Minimal type behaviour: todo gets due-by and done; habit gets a streak; idea gets a Sharpen entry
  point (inert until Phase 4).
- Settings shows honest intelligence status: on-device, fallback, or unavailable.

**Not in this phase.** Sharpen itself, clustering, nudge copy.

**Done when** — the app behaves correctly on a device with Apple Intelligence disabled; classification
never delays a save; a wrong classification is correctable in one tap and is remembered.

**Outcome.** Met, and delivered together with Phase 4's entry point.

- `HeuristicIntelligence` was written first, so every device has a complete app whether or not a
  model exists. `ResilientIntelligence` races the model against a timeout and degrades silently.
- Classification runs after the save returns and announces itself when it lands, because the
  on-device model genuinely takes seconds ([ADR-0014](DECISIONS.md)).
- A correction is one tap, and it is remembered: `kindSource` records that a human decided, so
  nothing overwrites it later.
- Settings reports which of the two is answering, in plain words.

---

## Phase 4 · Sharpen 🟢

The differentiator: half-baked in, fully-baked out.

**Scope**
- Interview flow — model reads the fragment, asks 2–3 short specific questions, one at a time.
- Answers persist as they're typed; the flow is resumable after backgrounding or force-quit.
- Write-up via `@Generable`: a short title and one paragraph developing the idea (ADR-0016).
- Streaming presentation, cancellation, retry, and a clear degraded state when no model is available.
- Raw captured text remains untouched and visible alongside the write-up.
- **Escalation:** an understated affordance that has the local model compose a context-loaded prompt
  and hand it to Claude/ChatGPT through the share sheet.

**Not in this phase.** Multi-turn open chat (explicitly rejected — see ADR-0006).

**Done when** — a one-line fragment becomes a write-up whose specifics all trace to a user answer;
interrupting mid-interview loses nothing; the feature fails gracefully and legibly without a model.

**Outcome.** Met. 147 unit tests and 22 UI tests.

- The heuristic write-up frames each answer with the question that produced it and joins them into a
  paragraph, inventing nothing. A test pins the exact sentences. It is the floor the on-device model
  has to beat.
- Sharpening is reversible: a confirmed *Revert* returns the note to exactly how it was captured.
- Every answer is written to storage as it is given. A UI test answers one question, leaves the
  screen entirely, returns, and finds the interview resumed rather than restarted.
- Changing an answer discards a write-up built on the old one ([ADR-0015](DECISIONS.md)).
- Five failure paths are covered: no questions, no write-up, a slow model, a model reporting itself
  unavailable, and a storage error. Each keeps the answers and says plainly what happened.
- Escalation composes a self-contained prompt and hands it to the share sheet, working with no model
  at all.

Also deferred from Phase 3 and delivered here: the Sharpen entry point, which is a swipe action on
idea rows rather than the inert button the plan originally described.

---

## Phase 5 · Review 🟢

The ritual that closes the loop opened in Phase 2.

**Scope**
- `ReviewSelector` in `Core` — pure, capped at seven, prioritising imminent expiry and repeat snoozes.
- Card stack: Act, Snooze, Drop. One card at a time, with progress and a real sense of an ending.
- Ambient sharpening — idea cards carry one generated question; answering it counts as acting.
- Entered from a quiet affordance or a notification. **Never** presented on launch (ADR-0008).
- A short post-session summary of what was decided.

**Not in this phase.** AI synthesis of weekly themes — deferred, revisit after this ships.

**Done when** — selection logic is covered across backlog sizes from zero to hundreds; a full session
takes under 90 seconds; skipping the review has no effect on the capture path.

**Outcome.** Met. 178 unit tests and 27 UI tests.

- `ReviewSelector` is pure and tested from an empty backlog to 300 thoughts, including the cap,
  ordering, ties, running snoozes, and terminal states.
- A UI test runs a whole session to its end and asserts it reports what was decided. Sessions are
  built once and never grow, so they always have a visible end.
- A UI test launches with a backlog that needs decisions and asserts the capture field is still
  focused with nothing presented over it.
- Letting go archives; a UI test then finds the thought in the archive. Nothing a review does
  destroys anything.
- Idea cards carry one generated question, and answering it counts as keeping the thought and seeds
  a real interview ([ADR-0017](DECISIONS.md)).

Deferred as planned: AI synthesis of weekly themes.

---

## Phase 6 · Ambient 🟢

Get the app out of the app — nudges and glanceable surfaces.

**Scope**
- Daily nudge: a background task composes tomorrow's copy with the on-device model from one genuinely
  forgotten thought, with a written fallback string when no model is available.
- Weekly review invitation and pre-archive expiry warning.
- Lazy notification permission, requested from Settings or after a first successful review.
- Home screen widget (inbox count + oldest fading thought) and lock screen quick-capture widget.
- Control Center capture control; App Intent so Siri and Shortcuts can capture into the inbox.

**Not in this phase.** Live Activities.

**Done when** — nudges arrive at the chosen time without the app running; every ambient surface writes
through the same repository as the app; nothing here can ever produce an in-app modal.

**Outcome.** Met. 208 unit tests and 30 UI tests.

- `NudgeSelector` and `NudgeScheduler` are covered without scheduling a real notification: permission
  gating, stale-queue replacement, per-kind switches, and the rule that the app only cancels
  identifiers it owns.
- Copy is composed ahead of time because the model cannot run at delivery ([ADR-0018](DECISIONS.md)).
- Permission is requested only from Settings. A UI test asserts a cold launch with a full backlog
  shows no alert and reaches a focused field.
- The store moved to an App Group so widgets read through the same repository; Settings says plainly
  when a build cannot share it.
- `CaptureThoughtIntent` captures by voice without opening the app.

Two rules were changed by building them: a thought expiring within the day now gets whatever notice
remains rather than being silently skipped, and only the soonest-expiring thought is warned about.

Deferred as planned: Live Activities.

---

## Phase 7 · Sync 🟢 *(one criterion unverified)*

**Scope**
- CloudKit private database via SwiftData; schema audited against CloudKit constraints.
- Versioned schema migration from the local-only store, with a documented rollback.
- Defined conflict policy (last-writer-wins on content; union on lifecycle events).
- Honest sync status in Settings; correct behaviour when the user isn't signed into iCloud.

**Done when** — two devices converge after edits made while both were offline; a signed-out user has a
fully functional local app with no errors.

**Outcome.** The second criterion is met and tested. **The first is unverified** — see below.
228 unit tests and 34 UI tests.

- The conflict policy turned out to be a *schema* decision. CloudKit merges a record column by
  column, so version 1's split lifecycle columns could produce a state neither device was ever in.
  A test demonstrates that tear, and another proves the new single-column shape cannot produce it
  ([ADR-0019](DECISIONS.md)).
- The migration is a custom stage, tested against a store written by the version 1 schema: a
  lightweight migration would have returned the entire archive to the inbox.
- The rollback is real rather than documented-in-principle: version 2 keeps writing version 1's
  columns, so an older build installed over this one reads correct data.
- A build that cannot reach iCloud opens a device-local store and behaves normally. Four UI tests
  cover it, including that nothing about signing in ever reaches the capture path.
- Settings says which of the two is happening, and never claims more than the storage underneath it.

**Not verified: two devices converging.** It needs two signed installs under one iCloud account.
This machine has no signing identity, so no build made here carries the CloudKit entitlement at all.
Everything that does not depend on it is covered.

Also changed here: CI now runs *every* package's unit tests. It had been running only `Core`'s and
merely building the rest, which would have let a broken `Persistence` test through.

---

## Phase 8 · Ship 🟢 *(one criterion unverified)*

**Scope**
- Full VoiceOver pass, Dynamic Type to accessibility sizes, Reduce Motion, contrast audit.
- Motion and haptics: the fade, the card stack, the save.
- Non-blocking first-run explanation — discoverable, dismissible, never modal.
- Empty and error states written as real copy, not placeholders.
- Performance: cold launch to focused field measured and budgeted; large-store scroll profiling.
- App icon, screenshots, privacy nutrition label (nothing leaves the device), TestFlight build.

**Done when** — the app is fully operable by VoiceOver at the largest Dynamic Type size, and a
TestFlight build is installed and used for a week of real capture.

**Outcome.** The first criterion is met and tested. **The second is not possible here** — see
below. 240 unit tests and 46 UI tests.

- The contrast audit is a **test**, not an opinion: every palette pairing the app draws is checked
  against WCAG AA in all four appearances ([ADR-0020](DECISIONS.md)). Running it found three real
  faults — the fade was unreadable at its old floor, one accent colour could not serve as both a
  fill and a text colour, and the app was overriding the appearance the user had chosen.
- Reduce Motion is honoured centrally. `Motion` had existed since Phase 0 and was applied nowhere,
  so there was nothing to honour it *with*; there is now one `View.motion(_:value:)` and it is the
  only way animation is applied.
- Four UI tests drive the app at the largest accessibility type size: capture, the inbox, the
  review's three decisions, and the names every control gives VoiceOver. The review's decisions
  stack rather than clip, and the freshness band is spoken in words instead of a percentage.
- The first-run explanation is one line under the field, retired by dismissing it *or* by
  capturing anything ([ADR-0021](DECISIONS.md)). Three UI tests assert it blocks nothing and never
  returns.
- Empty and error states are written copy. `storageIsDegraded` had been computed since Phase 1 and
  never shown to anyone — a store that failed to open now says so in the inbox and in Settings.
- The performance budget is a **ratio**, because an absolute one measures the test harness: a
  four-hundred-thought store must not cost more to launch than an empty one. Verified against the
  previous phase's build, `XCUIApplication.launch()` costs ~3s whatever the app does.
- App icon rendered from code so it can be regenerated ([docs/ASSETS.md](ASSETS.md)); privacy
  manifest declaring nothing collected and nothing tracked ([docs/PRIVACY.md](PRIVACY.md)).

**Not possible here: a TestFlight build used for a week.** TestFlight needs a Developer Program
membership, and this machine has no signing identity at all, so no build made here can be
distributed. It also needs a week. Everything that does not depend on either is done.

Also fixed here, from earlier phases: `ScreenshotTests` was waiting on a thought the demo seed had
not contained for several phases, so it silently timed out and shot whatever was on screen; and an
inbox edit test depended on which keyboard the simulator happened to show.

---

## Deferred

Recorded so they aren't rediscovered as new ideas later.

| Idea | Why not now |
|---|---|
| Voice capture with on-device transcription | Text-first was chosen; system dictation covers most of the need. Revisit if 1am capture proves hard. |
| Weekly AI synthesis of themes | Attractive but unproven; let the base ritual earn it first (ADR-0007). |
| Clustering related ideas | Needs embeddings and a real corpus of thoughts to be worth anything. |
| iPad and Mac targets | The architecture supports it; there's no demand yet. |
| Sharing or collaboration | Would require accounts and a backend, contradicting ADR-0003. |
