# Fleeting v2.1 — bugs and UX requests

Created: 2026-10-08 · Last updated: 2026-10-17

**Current phase: v2.1 accepted as complete (2026-10-17).** The user authorizes the README/screenshot
refresh, merge into main and remote push. B01–B12, Q01 and the later-authorized Q02 enhancement
are the accepted implementation scope. Preserve the detailed validation and live-device/service
limits below; implementation acceptance is separate from unobserved tester distribution or
cross-account acceptance. Log new app issues without fixing them unless separately authorized.
Earlier investigation and implementation notes remain as history.

Keep the original numbering and stable IDs when adding details or new reports. Distinguish
code-confirmed behavior, tested behavior, service observations, and hypotheses. A plausible cause
is not a reproduced failure; do not mark an item resolved without authorized work and verification.

## Investigation pass — 2026-10-08

Baseline: `development/2.1`, commit `4cc6cea`. Read the relevant navigation, views, models,
persistence, lifecycle, review and design tokens. Inspected CloudKit Console's Development and
Production record-type lists without changing schema or permissions. Existing focused tests passed:

- Persistence: `DailyTodoRepositoryTests|CollaborationStoreTests` — **15 tests**.
- Features: `PlanModelTests|InboxArchiveFilterTests|CloudDetailTests` — **12 tests** across three suites.

These tests validate existing storage/model behavior, not the new requested UI or one-day lifecycle.
No UI suite was run and no app/test source was changed. The existing iPhone 17 Pro simulator was
booted and the installed 2.0 app launched normally, without reset, seeding, reinstall or schema
initialization. Its code-signature entitlement dictionary is empty, so an Apple ID login alone
does not make that installed binary a suitable signed CloudKit sharing test. No live share was
created. Simulator UI automation was unavailable; no interactive reproduction is claimed below.

**User follow-up:** B05 and B10 occur on **both iPhone and simulator**. The user does not remember
the preceding action. Their exact causes remain unconfirmed.

## Bugs and requested changes

### 1. B01 — Sharing cannot generate links

**Reported:** The share feature fails to generate links and displays a Cocoa/iCloud error.
The simulator has an Apple ID signed in and can be used for reproduction later, after permission.

**Expected:** Sharing a list successfully generates a usable link.

**Evidence:** Two screenshots supplied in the initial report:

- An **iCloud Sharing** alert says the operation could not be completed because the mirroring
  delegate never successfully initialized. It reports `CKError "Partial Failure" (2/1011)` and
  `"Failed to modify some records"`. The nested `cloudkit.zoneshare` error reports
  `"Invalid Arguments" (12/2006)` with the server message
  `"Cannot create new type cloudkit.share in production schema"`, followed by
  `"Batch Request Failed"`.
- A **Couldn't Add People** alert says: **“A link couldn't be created for you to share.”**

The initial report transcribed these observations without diagnosing them. Investigation follows.

**Investigation — service configuration confirmed:** CloudKit Console for
`iCloud.com.himirdesai.Fleeting` lists `CD_DailyTodoEntity`, `CD_MemberActivityEntity`,
`CD_ThoughtEntity`, `CD_ThoughtListEntity` and `Users` in both Development and Production.
`cloudkit.share` is absent from both visible record-type lists. This directly matches the reported
server rejection. The earlier production schema deployment recorded in ROADMAP did not establish
that this sharing-specific type existed.

Apple's DTS explanation of the exact same server error identifies the missing Production sharing
type as the cause; creating a real share in Development normally creates that type. See
[Apple DTS: missing cloudkit.share in Production](https://developer.apple.com/forums/thread/841618).
The [Core Data sharing documentation](https://developer.apple.com/documentation/coredata/sharing-core-data-objects-between-icloud-users)
also distinguishes development schema creation from production deployment.

**Code evidence:** [prepareShare](../Packages/Persistence/Sources/Persistence/Sharing/CollaborationSharing.swift#L16)
calls Core Data's native share operation, then persists the updated share. The coordinator
[presents UICloudSharingController](../App/Sharing/ListSharingCoordinator.swift#L24) and surfaces
native errors. The DEBUG-only [schema initializer](../App/Sharing/DevelopmentCloudSchema.swift#L8)
initializes model schema only when explicitly requested; it is not evidence of a completed share.

**Still to verify later:** After an authorized schema repair, verify actual link creation and
acceptance on separate accounts using the intended signed build/environment. The second screenshot's
generic link error could conceal additional failures; resolving the identified prerequisite is not
proof that the complete sharing flow works. No schema initialization, share creation, deployment,
environment reset or permission change was performed during this investigation.

### 2. B02 — Archived thoughts need an accessible restore editor

**Reported:** Archived thoughts can currently only be restored by swiping right.

**Requested:** Tapping an archived thought opens the same edit-thought page used for normal
thoughts. Only **Unarchive / Mark as not done**, as appropriate, is available; other buttons stay
visible but are greyed out and disabled. The archived editor must not permit ordinary editing.

**User refinement — 2026-10-15:** Reuse the existing Archive action in the individual thought page:
it becomes **Unarchive** for an archived thought. Remove the separate restore button; other
restricted controls remain disabled.

**Task correction — 2026-10-15:** The supplied screenshot shows completed tasks with a disabled
Mark done action and a separate Mark as not done label in the Archive slot, making the five actions
fall into a grid. The **completion** action must switch between **Mark done / Mark not done**.
Archive/Unarchive retains its own slot; Archive is disabled for a completed task. Keep the actions
in one horizontal row. Equal-width slots and wrapping captions fit five controls at ordinary text
sizes; larger accessibility text can scroll the same row horizontally. Implementation complete;
all three focused UI checks pass, with normal/large-text screenshots visually checked.

**Related:** B09 uses this same editor behavior for completed Plan tasks.

**Investigation — code-confirmed:** [ArchivedListRow](../Packages/Features/Sources/InboxFeature/ArchivedListRow.swift#L10)
accepts only restore/delete callbacks and renders text with swipe actions. It has no open callback
or tappable navigation action. [InboxView](../Packages/Features/Sources/InboxFeature/InboxView.swift#L166)
wires archived rows this way, while live rows receive `onOpen`.

The existing detail screen has no archived/completed mode or restore action. Its disabling rules
mostly use [canEditContent](../Packages/Core/Sources/Core/Model/Thought.swift#L22), which checks
sharing permissions, not lifecycle state. Routing an archived row to it alone would leave editing
and ordinary actions enabled for private thoughts. The model already has a working restore path
in [InboxModel.restore](../Packages/Features/Sources/InboxFeature/InboxModel.swift#L278), and the
existing restore test passes.

**Verification needed for an eventual fix:** Open an archived thought by tapping, retain the normal
editor's controls visibly disabled, restore through the allowed action, and respect shared-list
viewer permissions. Completed tasks require the same restrictions with the appropriate undo label.

### 3. B03 — List sharing needs a top-level button

**Reported:** The share button is inside Edit List, making it hard to discover.

**Requested:** Add a fourth button, with a share icon, to the top-right pill on the list page.

**Investigation — code-confirmed omission:** [InboxView's pill](../Packages/Features/Sources/InboxFeature/InboxView.swift#L67)
contains Edit List for custom lists, the filter, and Settings. It has no sharing action. The existing
[sharing controls](../Packages/Features/Sources/InboxFeature/ThoughtListSharingControls.swift#L15)
are embedded in [ThoughtListEditorView](../Packages/Features/Sources/InboxFeature/ThoughtListEditorView.swift#L69).
The native sharing service already exists; the list destination does not receive a share callback.

**Scope to preserve later:** Personal Plan is explicitly protected from sharing. Owned lists and
received shares have different Share/Manage Sharing behavior and permission rules. A top-level
entry point must honor those rules and expose unavailable/error states; B01 remains a separate
service prerequisite. Four controls also need checking with long list names and large text.

### 4. B04 — Reset thought filters when switching main pages

**Reported:** An active thought-type/status filter (todo, archived, idea, habit) carries across pages.

**Requested:** Reset the filter to **All** whenever the user switches between the four main pages:
**Home, Thoughts, Lists, and Plan**. Preserve it when opening a thought or Settings and returning
to the same main page.

**Examples:** Plan → Thoughts, Plan → Home, and Lists → Thoughts must reset to All.

**Investigation — code-confirmed:** RootView constructs one `InboxModel` and supplies that same
instance to both Thoughts and Lists. [InboxModel.filter](../Packages/Features/Sources/InboxFeature/InboxModel.swift#L30)
is retained observable state. [selectTab](../App/Navigation/RootView.swift#L266) clears collection
selection and sometimes navigation, but never resets the filter. Loading also leaves it unchanged.
Home and Plan do not themselves display this thought filter; it persists when returning to the
destinations that use it.

**Verification needed later:** Test switches between all four distinct main pages, including
leaving and returning. Opening a thought or Settings must preserve the filter. Tapping the already
selected main tab is not a switch to a different page and should not accidentally reset it.

### 5. B05 — Random flickering of the top-right button pill

**Reported:** The app randomly flickers. The most noticeable area is the top-right button pill,
which turns white and flickers for several seconds.

**Expected:** The pill remains visually stable during normal use.

**Investigation — unresolved; rendering path identified:**
[ToolbarPill](../Packages/DesignSystem/Sources/DesignSystem/Components/ToolbarPill.swift#L11)
uses a single custom capsule with `.glassEffect(.regular.interactive())`. Its normal button press
style changes label opacity; there is no explicit white flashing animation or repeating timer in
this component. [PageHeader](../Packages/DesignSystem/Sources/DesignSystem/Modifiers/PageHeading.swift#L52)
hosts it in a top safe-area inset and changes layout with text size. The pill's children change
when selected-list metadata changes; inbox loads and keyboard/navigation changes also refresh
parts of the view hierarchy.

**Hypotheses, not established causes:** Liquid Glass compositing during layout/presentation changes,
or repeated view updates affecting the glass surface. The available evidence does not justify
calling this an Apple framework bug, a CloudKit bug, or blaming a particular animation.

**Next investigation:** Capture a failing sequence on phone or simulator, identify the affected
page/appearance and correlate it with navigation, keyboard and data changes. Observe whether
the pill's bounds/identity change while the glass goes white. A static screenshot or passing
model tests cannot prove or exclude a seconds-long rendering failure. No rendering workaround applied.

### 6. B06 — Home's selected-list indicator needs adaptive width

**Requested:** The selected-list indicator on Home resizes to fit its text, up to a maximum
allowed width. The maximum width has not yet been specified.

**Investigation — two code-confirmed constraints:** Home uses
[GlassListPicker](../Packages/Features/Sources/CaptureFeature/CaptureView.swift#L227).
Its label has [a fixed 96-point width](../Packages/DesignSystem/Sources/DesignSystem/Components/GlassListPicker.swift#L72)
and its [compactLabel](../Packages/DesignSystem/Sources/DesignSystem/Components/GlassListPicker.swift#L88)
cuts every selected name to ten characters before layout. Even changing the width alone would
leave that premature text truncation. The full name is available separately for accessibility.

**Open design detail:** Maximum width is unspecified. The available width must also leave space
for Home's save and keyboard-down controls. Future verification should include short/long names,
wide glyphs, larger text, and both states of the save control; truncation should depend on the
actual capped space rather than character count.

### 7. B07 — Switching tabs exposes the thought editor's dismissal

**Reported:** When editing a thought on Thoughts and switching to another page such as Lists,
the destination switches first, then the edit-thought page visibly slides out.

**Requested:** Switch main pages instantly. Remove the thought editor in the background so the
user never sees its dismissal animation over the destination.

**Investigation — code-supported navigation hypothesis; animation not reproduced:**
[Thoughts and Lists](../App/Navigation/RootView.swift#L93) each create a NavigationStack, but both
bind detail/review/sharpen destinations to the same `opened`, `isReviewing` and `sharpening` state
in [thoughtsTab](../App/Navigation/RootView.swift#L349). Entering Lists clears that state through
`showThoughtsRoot` and changes tab selection in the same update, without an explicit nonanimated
navigation transaction. Entering Home or Plan does not clear the thought detail state at all.
This creates coupled stacks and inconsistent cleanup; it fits the reported visible pop, but code
inspection alone does not establish the exact rendered frame ordering.

**Dependency:** [ThoughtDetailView.onDisappear](../Packages/Features/Sources/InboxFeature/ThoughtDetailView.swift#L108)
currently saves edited text asynchronously. Changing dismissal/navigation later must preserve
that save behavior and avoid stale copies overwriting the same thought. Plan also has its own
detail navigation state that needs checking on tab switches.

**Next verification:** Record Thoughts-detail → Lists/Home/Plan transitions frame by frame, including
an unsaved text edit, then verify the saved text and return navigation. No navigation code changed.

### 8. B08 — Lists navigation must open, rather than toggle, the selector

**Requested:** Tapping **Lists** in the main navigation always opens the list selector. If the
selector is already open, tapping Lists does nothing and leaves it open.

The selector closes only when the user switches to another page or selects an option in the
selector. Tapping Lists again must not close it.

**Investigation — confirmed dismissal gap; repeated-tap behavior still needs reproduction:**
[selectTab(.lists)](../App/Navigation/RootView.swift#L266) already assigns `isChoosingList = true`;
there is no application-level `toggle()` here. The selector is a native tab-anchored popover with
a writable presentation binding. Native dismissal can reset that binding without selecting a
list or switching pages, as described by Apple's
[presentation documentation](https://developer.apple.com/documentation/swiftui/view-presentation).
There is no application-level dismissal restriction in this presentation.

The existing [NativeNavigationTests](../Tests/UITests/NativeNavigationTests.swift#L6) explicitly
expects an outside tap to close the popover, contrary to the new request. It checks reopening an
already selected Lists tab after choosing a list, but not tapping Lists while the chooser is
already open. It must not be used as proof that repeated-tap behavior meets the new requirement.

**Next verification:** Separately test a repeated Lists tap, outside tap, switching to another
main page, and each selector option. Observe whether native popover dismissal happens before or
after the selection callback. Do not assume changing `true` to `true` alone solves native dismissal.

### 9. B09 — Completing a task in Plan is not reflected in its editor

**Reported:** After marking a task done on Plan, opening that task still offers **Mark done**,
indicating that completion is not reflected in the task in the Plan list.

**Requested:** Completion from Plan is reflected consistently. Opening a completed task shows
the restricted editor described in B02, with **Mark as not done** available instead of Mark done.

**Investigation — editor defect confirmed; missing persistence not established:**
[PlanModel.decide](../Packages/Features/Sources/PlanFeature/PlanModel.swift#L125) persists completion
through [ThoughtListTaskRepository](../Packages/Persistence/Sources/Persistence/Repositories/ThoughtListTaskRepository.swift#L35).
That repository calls `Thought.complete`, saves the original thought, and derives the checklist's
completion from `.done(at:)`. RootView opens the detail by fetching that same thought ID from
the repository. The focused persistence tests pass for task completion, cross-repository reads
and shared completion.

However, [ThoughtDetailView.kindAction](../Packages/Features/Sources/InboxFeature/ThoughtDetailView.swift#L193)
returns **Mark done for every todo**, without inspecting its state. `canEditContent` tests share
access only, so a completed private todo still gets that button and the ordinary editing controls.
This explains the user's evidence even when completion has been saved correctly.

**Additional consequence:** Pressing that detail action calls `Thought.complete` again, replacing
the completion timestamp. Once B11 uses that timestamp for delayed archiving, a redundant completion
could incorrectly restart the delay. Preserve completion identity/date until an explicit reopen.

**Next verification:** After completing a Plan row, open its detail and correlate the persisted
state with enabled controls. The present evidence supports a lifecycle-aware editor issue, not
a proven database write failure. B02 and B09 should share the eventual editor behavior.

### 10. B10 — Plan's keyboard-dismiss button is sometimes missing

**Reported:** The keyboard on Plan sometimes lacks the keyboard-down/dismiss button.

**Expected:** The dismiss button is consistently available when the keyboard is shown on Plan.

**Investigation — code-supported visibility-state hypothesis; intermittent failure not reproduced:**
[PlanView](../Packages/Features/Sources/PlanFeature/PlanView.swift#L65) attaches the common dismiss
modifier. [KeyboardDismissControl](../Packages/DesignSystem/Sources/DesignSystem/Modifiers/KeyboardDismissControl.swift#L24)
renders the button only when **both** local focus and observed keyboard visibility are true.
[KeyboardVisibility](../Packages/DesignSystem/Sources/DesignSystem/Modifiers/KeyboardVisibility.swift#L27)
starts each observer at `false` and learns visibility only from later frame/hide notifications.
It does not initialize from an already-visible keyboard or reconcile state on presentation reentry.
The local observer shadows the one attached to RootView, and screen bounds come from the first
connected scene rather than explicitly the active input's scene.

**Hypothesis:** During focus/tab/presentation handoffs, the keyboard can remain visible while the
new or stale local observer says false, suppressing the button. That is a plausible race, not a
confirmed explanation for every occurrence. The existing Plan UI test covers straightforward
focus/Return/dismiss and deliberately omits the button for a hardware-only keyboard; it does not
cover repeated focus handoffs, returning from detail/Settings, or an already-visible keyboard.

**Next verification:** Correlate input focus, actual keyboard frame and observer state in a failing
sequence on both environments. Check reentry, interactive dismissal and hardware keyboard cases.
No visibility code or device keyboard settings changed.

### 11. B11 — Task rows and completion lifecycle should match Plan

**Reported:** On Thoughts and Lists, task thoughts display a tick type icon on the left and a
separate green tick action on the right.

**Requested:** Use the Plan-style task presentation and completion behavior:

- Show an empty circle when the task is incomplete.
- Show a checked circle and strikethrough text when it is complete.
- Archive completed tasks **one day after completion**, instead of immediately.
- Completed tasks must not appear in reviews.

**Related:** B02 and B09 define the restricted editor for completed/archived tasks; Q01 concerns
the placement of the completion action inside the editor.

**Investigation — presentation and lifecycle gaps confirmed:**
[InboxListRow](../Packages/Features/Sources/InboxFeature/InboxListRow.swift#L24) independently draws
the leading `KindGlyph` and a trailing completion chip. The todo glyph is always `checkmark.circle`;
neither glyph nor ThoughtRow text reflects completion. Plan has the requested circle/check behavior
in [PlanTodoRow](../Packages/Features/Sources/PlanFeature/PlanTodoRow.swift#L12) and strikethrough
in `PlanTaskText`, which belongs to the Plan feature and cannot simply be imported by Inbox.

Completion immediately sets `.done(at:)`. [ThoughtState.isLive](../Packages/Core/Sources/Core/Model/ThoughtState.swift#L31)
excludes `.done`, [InboxModel.complete](../Packages/Features/Sources/InboxFeature/InboxModel.swift#L249)
removes the row immediately, and repository `.archived` scope includes all nonlive states, including
done. There is also an inconsistency: the immediate in-memory completion path inserts into the
archive only for `.archived`, so a done task appears in Archived only after a reload. The existing
archive test explicitly checks that it does not appear there immediately after completing.

[ArchiveSweeper](../Packages/Persistence/Sources/Persistence/Maintenance/ArchiveSweeper.swift#L27)
reads only live thoughts and excludes todos/Plan. No one-day post-completion archive rule exists.
Plan's task projection deliberately retains `.done` history, without a one-day cutoff.

**Behavior already present:** Completed tasks are excluded from thought reviews by
`ReviewSelector`'s `isAwake` guard and from pending Plan reviews by `DailyTodo.needsReview`.
Keeping completed tasks visible for a day later must not accidentally make them review-eligible.

**Open lifecycle decisions:** Does “one day” mean 24 hours after completion or the next calendar
day? Should Plan retain completed history after tasks disappear from Thoughts/Lists? Shared thoughts
currently archive only manually: confirm whether completed shared tasks get this automatic delay too.
Changing `.done` to `.archived` naively would lose the completion meaning/date and remove Plan's
completed history. Preserve identity, completion history and undo semantics across the transition.

### 12. B12 — Remove expiry-based thought thickness entirely

**Requested:** Remove the entire feature that changes a thought's thickness according to how
soon it will expire. Remove all code and artifacts for that feature and repair all affected
dependencies when implementation is authorized.

This request concerns the expiry-based **thickness treatment**; no broader removal of thought
expiration or archiving has been requested.

**Investigation — removal boundary identified:** The active expiry-based text-thickness treatment
is [ThoughtRow's fontWeight](../Packages/Features/Sources/InboxFeature/ThoughtRow.swift#L24), backed by
[FreshnessStyle.weight](../Packages/DesignSystem/Sources/DesignSystem/Tokens/FreshnessStyle.swift#L38).
It maps freshness ≥0.66 to semibold, ≥0.33 to medium, and lower values to regular. Search found one
production call site for this helper, shared by Thoughts and Lists.

**Artifacts affected later:** That call, its now-unused weight helper, and comments presenting
freshness as font weight in ThoughtRow, ArchivedListRow and FreshnessStyle. ADR-0025 documents the
old choice and ADR-0035 refers to it; record the new decision as superseding that treatment without
erasing historical ADRs. No dedicated weight-mapping test was found in DesignSystem.

Other `FreshnessStyle` functions control opacity, card fill/elevation, rail and meter colors.
Expiration drives archiving, urgency, reviews, notifications and widgets independently of this font
weight helper. `FreshnessMeter.thickness` is a fixed meter height, not expiry-based thought text
thickness. These are separate dependencies, so removing the entire style/decay subsystem would
exceed the requested change. No code or feature was removed during investigation.

## Quality of life / UX

### 1. Q01 — Mark done looks like the action for saving edits

**Reported:** In a task thought's editor, **Mark done** is large and centrally placed. After
editing, a user may mistake it for the action that finishes and saves their edits.

**Requested:** Move or restyle the completion action so it is out of the way of the editing/save
flow, while remaining immediately discoverable when the user wants to complete the task.
It must be clearly distinguishable from saving edits. Exact design is deferred until permission.

**Investigation — code-confirmed hierarchy conflict:**
[KindActionButton](../Packages/Features/Sources/InboxFeature/KindActionButton.swift#L22) uses title
type, large padding, full available width and a solid accent background. ThoughtDetailView places
it prominently between properties and expiry/actions. Meanwhile, text editing has **no explicit
Save/Done control**: [onDisappear](../Packages/Features/Sources/InboxFeature/ThoughtDetailView.swift#L108)
commits the draft when leaving. This makes the strongest button look like the missing editing
confirmation even though it changes task lifecycle.

**Additional investigation finding:** Completion persists `model.thought`, not the current draft,
then dismisses; disappearance subsequently attempts to save that draft asynchronously. A future
placement change must account for this ordering and make editing persistence unambiguous, alongside
B07's navigation/save behavior and B09's lifecycle restrictions. No lost edit is claimed from code
inspection alone.

**Verification needed later:** A user can identify how edits are saved and distinguish that from
task completion; completion stays easy to find when intended. Preserve habit-action behavior,
accessibility targets and shared-list permissions. No visual redesign applied.

### 2. Q02 — Show source lists during global thought reviews

**Status:** Implementation authorized on 2026-10-15. Source-list labels and global review copy
implemented; 18 ReviewModel tests and both focused UI checks pass.

**Requested:** Keep thought reviews global across lists, regardless of the page/list used to open
Review. Show which list each reviewed thought belongs to, with a clear label for unfiled thoughts.
Review invitations on frequently used pages should communicate the global need for review, so
people discover thoughts in lists they have forgotten to open. Make the invitation's global scope
clear when entering from a particular list.

**Why:** Someone with ten lists should not have to visit each one to review. A list created three
months ago may never be reopened; its eligible thoughts still need to resurface elsewhere.

**Acceptance for a future implementation:** Review cards identify their source list, entering from
one list continues to surface eligible thoughts across all lists, and review counts/invitations
retain that global scope. Existing review eligibility and session limits continue to apply.
The existing Thoughts/Lists invitation now says **Across all lists**, and the session header says
**Thoughts from across all lists**. Each card shows its named list or **No list** for unfiled
thoughts. Unavailable metadata uses **List unavailable**; known names survive a failed refresh.
Names refresh with store changes without restarting the review or resetting completed decisions.

**Validation:** After implementation, 18 ReviewModel tests pass, including cross-list selection,
source names, unfiled/unavailable labels, renames, retained context on read failure and preserved
decisions. Two focused UI cases pass: review entered from a selected list shows both a named list
and No list, and review decisions remain reachable at the largest Dynamic Type size. Captured
normal/large-text screenshots were visually checked; the long source name is readable and the
metadata wraps at accessibility sizes. SwiftFormat lint and `git diff --check` pass.
Logs: `/tmp/fleeting21-review-context-model.log`, `/tmp/fleeting21-review-context-ui.log`;
result/screenshots: `/tmp/fleeting21-review-context.xcresult`,
`/tmp/fleeting21-review-context-images/`. The full UI suite was not run.

**Related:** N01 is confirmed intentional behavior, not a list-scoping bug. See ADR-0071.

## Dependencies and remaining uncertainties

- **B02 + B09 + Q01:** One lifecycle-aware editor, with clear restore/reopen and edit-saving behavior.
- **B11:** Completion visibility, delayed archive, history and review exclusions must agree with that editor.
- **B04 + B07 + B08:** Main-page navigation owns filter reset, background detail cleanup and selector behavior.
- **B03 + B01:** The new entry point and working cloud link generation are distinct acceptance checks.
- **B05 + B10:** Remain open investigations requiring captured failures. B07's exact animation ordering
  and B08's repeated-tap event ordering also need runtime evidence.
- **Product details still open:** B06 maximum width; B11 delay boundary, Plan history and shared-task policy;
  Q01 final editing/completion presentation. None of these authorizes implementation by itself.

## Report history

- **2026-10-08:** Recorded the initial 12 bugs/requested changes and one UX request, including
  the supplied sharing-error screenshots. Collection only; no investigation or fixes authorized.
- **2026-10-08:** User authorized investigation only. Recorded a source review for all 13 items,
  read-only CloudKit schema observations, 27 passing existing focused tests, simulator signing
  limitations and the user's phone/simulator follow-up for B05/B10. App code and CloudKit
  configuration unchanged; fixes remain unauthorized.


## Implementation — 2026-10-15

Implementation was completed before running tests, as requested. Final validation results and
remaining service/device limits are recorded below.

| Reports | Implementation | Status |
| --- | --- | --- |
| B01 | Explicit DEBUG sharing-type initialization in an empty disposable Development zone; present Core Data's persisted share | **Schema repair verified:** Production has cloudkit.share and generates a real share URL; native-list/two-account acceptance remains unverified |
| B02, B09 | Tappable archive rows; lifecycle-aware detail with only restore/reopen enabled; Archive switches to Unarchive for archives; task completion switches to Mark not done for completed tasks; permission guards | All three corrected task/archive/largest-text UI checks pass; screenshots checked |
| B03 | Fourth custom-list toolbar action invokes existing native share/manage service | Toolbar UI check passes; actual link creation remains B01 |
| B04, B07 | Separate per-tab routes; nonanimated cleanup and filter reset only on main-page switches | Filter/Settings, editor removal and draft persistence UI checks pass; exact animation frames not measured |
| B05 | Stable themed capsule replaces the pill's live interactive glass effect | Remediation builds and survives exercised flows; intermittent phone flicker still needs observation |
| B06 | Full label measured naturally, capped at 180 points and available width | Short/long label sizing UI check passes |
| B08 | Native popover dismissal guard with native tab-bar touch passthrough | Native-tab, repeated/outside-tap and option-selection UI checks pass |
| B10 | Shared keyboard state, active-window geometry and visibility reconciliation on reentry | Plan keyboard tab/Settings reentry and existing Return/dismiss UI checks pass; original random trigger unknown |
| B11 | Completed circles/strikethrough; 24-hour display-to-archive transition retaining done date and Plan history; reviews remain excluded | Core/model boundary, repeat-completion, review exclusion and Plan persistence checks pass |
| B12 | Remove expiry-based font-weight function, call site and obsolete active-code comments | Source search finds no remaining Swift dependency; package tests and app build pass |
| Q01 | Task completion moved into secondary actions; explicit Save; draft saved with completion | Draft/completion model checks and edit-persistence UI check pass |
| Q02 / N01 clarification | Source-list context on review cards; global scope in Thoughts/Lists invitations and session header | 18 ReviewModel tests, cross-list entry UI and largest-text review UI pass; screenshots checked |

The one-day interpretation is 24 hours after completion; Plan history is retained. Shared completed
tasks use the same visibility boundary without changing the shared record's lifecycle date.
This avoids depending on a particular participant or background sweep to perform an archive write.

### Final validation — 2026-10-15

- **372 package tests pass:** Core 124, DesignSystem 22, Features 114, Persistence 52,
  isolated SchemaMigration 12, Intelligence 36, Notifications 12. Persistence and migration used
  separate processes. Logs: `/tmp/fleeting21-{core,design,features,persistence,migration,intelligence,notifications}.log`.
- **Nine distinct targeted UI cases pass** across the final validation runs: V21RegressionTests
  (five), NativeNavigationTests (two), and PlanTests' Return/keyboard and persisted completion
  cases (two). Tests use the isolated **Fleeting v2.1 Regression** iOS 27 simulator; no reset/seeding
  was performed on the user's signed-in simulator. The full UI suite was not run.
- The first UI pass exposed a blank chooser caused by delegate forwarding and presentation inside
  a nonanimated transaction. Explicit delegate forwarding and separate chooser presentation fixed
  it; both native-navigation cases and the list sizing/share case passed on rerun. The draft-save
  assertion originally searched an offscreen virtualized row; filtering to Ideas and locating the
  row button verifies the saved text and now passes. Evidence: `/tmp/fleeting21-ui.xcresult`,
  `/tmp/fleeting21-navigation.log`, `/tmp/fleeting21-edit.xcresult`.
- Debug app/test compilation and optimized **Release app + widget simulator builds pass**.
  Changed Swift files pass SwiftFormat lint; `git diff --check` passes. No release/upload performed.
- B05's intermittent phone behavior and B07's exact rendered transition frames have not been
  observed directly; model/UI success is not proof of every random rendering sequence.

### B01 execution/access limit — still open

The earlier attempt failed before showing a computer-access prompt (`Sky Computer Use native pipe
startup failed`). Apple Development signing of the temporary fixture build failed with
`errSecInternalComponent`; an ad-hoc Development-entitled copy installed but iOS refused to launch
it. The normal simulator app was restored and launched without reset. The schema helper did not
execute, and no sharing schema or Production configuration change is claimed.

The first browser-free attempt, `xcrun cktool get-teams`, reported **no management token**
in arguments, environment or built-in storage. The retry below supersedes that authentication blocker. Apple's supported
[cktool workflow](https://developer.apple.com/icloud/ck-tool/) requires a locally saved management
token, exports either environment, and documents schema imports for Development. The documented
[Production promotion](https://developer.apple.com/documentation/CloudKit/deploying-an-icloud-container-s-schema)
uses Console's Deploy Schema Changes. No unsupported authenticated endpoint was assumed. A token
can be saved locally with `xcrun cktool save-token --type management`; do not put credentials in
this file or chat. B01 still requires Development share creation, reviewed Production deployment,
and actual link creation/acceptance verification. No environment reset or user-data deletion is
part of this repair.

### B01 authenticated retry — 2026-10-15

- Management authentication now succeeds: `cktool get-teams` returns the intended developer team.
  Exported Development and Production schemas successfully using the saved token, without reading
  the token itself or putting credentials into commands, logs or this file. The two exports are
  identical and contain the four app record types plus Users, with no `cloudkit.share` declaration.
  Snapshots: `/tmp/fleeting21-development.ckdb` and `/tmp/fleeting21-production.ckdb`.
- Apple Development signing also succeeds now. Directly signing iOS entitlements into the temporary
  fixture still caused simulator launch error 163. A temporary **CloudKit-only Xcode project**
  resolves that launch issue using Xcode's standard simulator entitlement handling; verified its
  `app-Simulated.xcent` specifies **Development** and only Fleeting's intended container. This is
  separate from the normal app and never opens its thought database or initializes Core Data.
  An empty code-signature entitlement dictionary alone is therefore insufficient to judge a
  simulator binary: inspect its simulated entitlements too. This qualifies the October 8 note.
- The Xcode-built helper launches, but repeatedly receives `CKAccountStatus.temporarilyUnavailable`
  (raw value 4). A read-only identity lookup succeeds; the subsequent account-status check still
  returns 4. The zone/share write guard never passes. **No fixture zone, share, schema import or
  Production deployment occurred.** Apple's [account-status guidance](https://developer.apple.com/documentation/cloudkit/ckaccountstatus/temporarilyunavailable)
  says the iCloud account exists but is not ready for CloudKit operations; wait for available status.
- The original installed app was backed up, restored after the attempts, and confirmed to launch
  normally. No data-container reset, seeding or deletion was performed. The simulator remains
  booted for the user to check Settings → Apple Account → iCloud for verification/setup prompts.
- Computer access still fails at native-pipe startup. Management API authentication is resolved;
  current blockers are simulator iCloud readiness for native share creation and Console access for
  the documented Production promotion. B01 remains open. Logs:
  `/tmp/fleeting21-schema-xcode.log`, `/tmp/fleeting21-schema-xcode-run.log`,
  `/tmp/fleeting21-schema-account-final.log`.

### B01 after simulator iCloud relogin — 2026-10-15

- The simulator now reports the account **available**. The isolated, Development-entitled
  CloudKit-only helper successfully creates a new empty zone, saves a real `CKShare`, and confirms
  that its URL is populated. It then successfully deletes that same fixture zone. No participants
  were added and no thought-store access, reset or seeding occurred. The deleted fixture's URL is
  not a persistent invitation and does not establish cross-account acceptance.
- The original app was backed up again, restored after the helper completed, and confirmed to
  launch normally. Log: `/tmp/fleeting21-schema-relogin-run.log`.
- Fresh authenticated exports confirm **Development now contains `cloudkit.share` and Production
  does not**. The exact schema delta is one added system record type, with its standard metadata
  and `cloudkit.thumbnailImageData`, `cloudkit.title`, `cloudkit.type` fields and generated grants.
  There are no modifications to the four existing app types or Users. Snapshots:
  `/tmp/fleeting21-development-after-share.ckdb`, `/tmp/fleeting21-production-after-share.ckdb`.
- Production **validation only**, with no import, returns:
  `BadRequestException: endpoint not applicable in the environment 'production'`.
  Computer access still returns `Sky Computer Use native pipe startup failed`, so the reviewed
  Production deployment cannot be completed through the currently available interfaces.
- User-facing next step: CloudKit Console → `iCloud.com.himirdesai.Fleeting` → Development →
  **Deploy Schema Changes**; confirm that the only new record type is `cloudkit.share`, then Deploy.
  Authorization for B01 already exists; this manual handoff is needed because computer access
  fails, not because another approval is required. Afterward, export Production to confirm the
  type and verify actual Production link creation. B01 remains open until that verification.

### B01 Production verification — 2026-10-15

- After the user's Console deployment, an authenticated Production schema export confirms that
  `cloudkit.share` is present. The complete Production schema now matches the reviewed Development
  export byte-for-byte. Comparing with the pre-deployment Production export shows exactly the
  expected added system type; no existing app record types, fields or grants changed.
  Snapshot: `/tmp/fleeting21-production-verified.ckdb`.
- Verified the isolated helper's Xcode-generated simulator entitlements explicitly specify
  **Production** and `iCloud.com.himirdesai.Fleeting`. With the account available, it successfully
  created an empty Production zone, saved a real `CKShare`, confirmed a populated share URL, and
  deleted that same fixture zone. Log: `/tmp/fleeting21-production-share-verification.log`.
- The currently installed app was backed up before this check, restored immediately afterward,
  and confirmed to launch normally. The helper did not open the thought database, add participants,
  reset/seed/delete the data container, or retain the empty test zone.
- **The missing-Production-type configuration fault is repaired and Production share/link
  generation is verified.** The deleted fixture's URL is not a live invitation. This primitive
  check does not establish the native list-sharing UI/Core Data flow or invitation acceptance and
  collaborative editing on a second account; those acceptance checks remain unverified. No extra
  code changes or release/upload were performed during this verification.

## Newly discovered issues — logged only

### N01 — Global review scope confirmed intentional

**Disposition — 2026-10-15:** Closed as intended behavior after user clarification. Preserve the
global review count/session even when Review opens from a selected list.

**Source observation retained:** `InboxModel.load` calculates `reviewCount` from the entire
`thoughts` array. `RootView.thoughtReview` creates a ReviewModel without the selected-list scope.
This lets eligible thoughts from forgotten lists resurface through a review opened elsewhere.

**Product rationale:** A person with ten lists should not have to open each list to review. A list
created three months ago and forgotten must still contribute eligible thoughts to global review.
The earlier suggestion to restrict Review to the selected list is withdrawn.

**UX follow-up:** Q02 records source-list labels on review cards and clear global review invitations.
No review-scoping code was changed. See ADR-0071.

### N02 — Existing review completion wording accepted

**Disposition — 2026-10-15:** Closed as accepted behavior. The user confirms the current wording is
fine; preserve the existing **Back to Thoughts** label and dismiss behavior.

**Source observation retained:** `ReviewView.summary` uses this label for the same review opened
from Thoughts or Lists. No completion-label or navigation change is part of Q02.

### N03 — Task expiry wording can imply automatic archiving (logged only)

**Discovered during README screenshot review — 2026-10-17.** Active to-dos still show copy such
as “archives tomorrow” in Thoughts and “Archives tomorrow” on thought-review cards, although
`ArchiveSweeper.sweep()` explicitly excludes unfinished to-dos and the built-in Plan list from
automatic expiry archiving. This is a presentation/lifecycle wording mismatch, not evidence that
an unfinished task was actually archived. Screenshot evidence:
`screenshots/v2.1/light/02-thoughts.png` and `screenshots/v2.1/review-source-lists.png`.

`ThoughtRow.metadata` and `ReviewView` display the freshness expiry date using archive wording;
the protected-task behavior remains unchanged. Future wording should distinguish freshness from
automatic archiving for protected tasks. No app change or additional reproduction was attempted;
deferred to separately authorized work after the accepted v2.1 baseline.

## Documentation and integration

**2026-10-17:** The user accepts v2.1 as complete and authorizes the current README/screenshots
refresh, merge into main and remote push. README now describes current features, four-tab routes,
completion/archive rules, global review, package dependencies and control/data flow. The screenshot
refresh adds 36 current light/dark tour captures and retains two v2.1 refinement captures with
documented provenance. The two selected screenshot tours pass in each appearance after correcting
the new driver's initial empty-field wait to account for iOS exposing its placeholder value.
That correction changes only screenshot automation, not app behavior. N03 is logged without a fix.
GitHub Markdown rendering, local links/images, image integrity, formatting and diff checks are
verified before integration. Historical source-test and distribution evidence above is retained.

## Implementation history

- **2026-10-15:** User authorized fixing existing reports only, logging new issues without fixing
  them, and running tests only at the end. Implementation recorded above; N01 logged without a fix.

- **2026-10-15, review clarification:** User confirms N01's global review scope is intentional.
  Closed N01 as expected behavior and recorded Q02 for source-list context/global review invitations.
  Documentation only; review logic and app UI are unchanged.

- **2026-10-15, archive action refinement:** User requests the existing Archive action become
  Unarchive in archived detail, replacing the separate restore button. Implemented the same action
  slot for restore/reopen, retaining model guards and disabled editing. Both existing focused UI
  cases pass after implementation, including restore/reopen and absence of the separate button.
  Result: `/tmp/fleeting21-archive-action.xcresult`; SwiftFormat lint and `git diff --check` pass.

- **2026-10-15, Q02 implementation:** User authorizes the N01-related UI enhancement. Added source
  list labels to review cards and global-scope text to the existing invitation/session. Kept global
  selection and eligibility rules intact. User accepts N02 as-is; closed without app changes.
  18 ReviewModel tests and both focused UI cases pass; screenshots, formatting and diff checked.

- **2026-10-15, completed-task action correction:** User requests Mark done toggle to Mark not done
  in its own slot, retaining Archive/Unarchive separately and all actions in a row. Implemented
  completion/restore routing in the first slot, archive-only restore in the archive slot, equal-width
  horizontal action layout and centered wrapping captions. All three focused UI cases pass after
  implementation: active/completed task actions, archive restore, and the largest text size. They
  verify five controls share a row, all fit the normal viewport, completion/reopen works through
  the same slot, and completed Archive stays disabled. Normal/large-text screenshots visually
  checked. Evidence: `/tmp/fleeting21-task-action-row.xcresult`,
  `/tmp/fleeting21-task-action-row-images/`, `/tmp/fleeting21-task-action-row.log`.
  SwiftFormat lint and `git diff --check` pass. No unrelated fixes or full UI suite run.

- **2026-10-15, alpha publication authorized:** Normally signed version 2.1 (5) archived and
  uploaded successfully with Production CloudKit and Apple's TestFlight Internal Only restriction.
  Both the local export and exact uploaded package pass app/widget distribution capability and
  signature checks. Apple acknowledged processing; final processing/Internal Tester Group
  availability remains unverified while browser connection is unavailable. See
  [INSTALL.md](INSTALL.md) for artifacts and the remaining distribution check. No external group
  was modified, and no unrelated app fixes or additional source tests were run for release metadata.

- **2026-10-16, external beta upload:** User additionally authorizes the existing external beta
  group. Version 2.1 (6) uploaded successfully with external testing eligibility, using the same
  validated app source. The local export and exact upload-staged app/widget package pass signing
  and capability checks. Apple acknowledged processing. Browser access still returns no available
  browser, so external-group assignment, beta review submission and tester availability remain
  incomplete; no external group has been changed. [INSTALL.md](INSTALL.md) records artifacts and
  the precise remaining handoff. No unrelated fixes or repeat source tests were introduced.
