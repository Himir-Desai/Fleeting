# Fleeting v2.1 — bugs and UX requests

Created: 2026-10-08 · Last updated: 2026-10-08

**Current phase: investigation authorized; fixes not authorized.** On 2026-10-08 the user said:
“start interrogating the bugs do not fix them yet.” Keep collecting reports, investigating them,
and maintaining this file. Do not change app code, deploy or initialize CloudKit schemas, or
implement any item until the user explicitly authorizes fixes. This includes the feature removal
and UX request. No reported item has been fixed.

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
