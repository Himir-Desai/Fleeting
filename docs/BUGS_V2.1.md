# Fleeting v2.1 — bugs and UX requests

Created: 2026-10-08 · Last updated: 2026-10-08

**Current phase: collecting reports only.** Maintain this file as the user adds reports over the
next day or two. Do not reproduce issues, investigate causes, run the simulator to check them,
design implementations, or change app code until the user explicitly authorizes that work.
This restriction applies to every item, including the feature removal and UX request.

All reports below are user-reported and **awaiting permission**. Nothing has been investigated or
fixed. Keep the original numbering and stable IDs when adding details or new reports; do not mark
an item resolved without authorized work and verification.

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

These are transcribed observations, not a diagnosis.

### 2. B02 — Archived thoughts need an accessible restore editor

**Reported:** Archived thoughts can currently only be restored by swiping right.

**Requested:** Tapping an archived thought opens the same edit-thought page used for normal
thoughts. Only **Unarchive / Mark as not done**, as appropriate, is available; other buttons stay
visible but are greyed out and disabled. The archived editor must not permit ordinary editing.

**Related:** B09 uses this same editor behavior for completed Plan tasks.

### 3. B03 — List sharing needs a top-level button

**Reported:** The share button is inside Edit List, making it hard to discover.

**Requested:** Add a fourth button, with a share icon, to the top-right pill on the list page.

### 4. B04 — Reset thought filters when switching main pages

**Reported:** An active thought-type/status filter (todo, archived, idea, habit) carries across pages.

**Requested:** Reset the filter to **All** whenever the user switches between the four main pages:
**Home, Thoughts, Lists, and Plan**. Preserve it when opening a thought or Settings and returning
to the same main page.

**Examples:** Plan → Thoughts, Plan → Home, and Lists → Thoughts must reset to All.

### 5. B05 — Random flickering of the top-right button pill

**Reported:** The app randomly flickers. The most noticeable area is the top-right button pill,
which turns white and flickers for several seconds.

**Expected:** The pill remains visually stable during normal use.

### 6. B06 — Home's selected-list indicator needs adaptive width

**Requested:** The selected-list indicator on Home resizes to fit its text, up to a maximum
allowed width. The maximum width has not yet been specified.

### 7. B07 — Switching tabs exposes the thought editor's dismissal

**Reported:** When editing a thought on Thoughts and switching to another page such as Lists,
the destination switches first, then the edit-thought page visibly slides out.

**Requested:** Switch main pages instantly. Remove the thought editor in the background so the
user never sees its dismissal animation over the destination.

### 8. B08 — Lists navigation must open, rather than toggle, the selector

**Requested:** Tapping **Lists** in the main navigation always opens the list selector. If the
selector is already open, tapping Lists does nothing and leaves it open.

The selector closes only when the user switches to another page or selects an option in the
selector. Tapping Lists again must not close it.

### 9. B09 — Completing a task in Plan is not reflected in its editor

**Reported:** After marking a task done on Plan, opening that task still offers **Mark done**,
indicating that completion is not reflected in the task in the Plan list.

**Requested:** Completion from Plan is reflected consistently. Opening a completed task shows
the restricted editor described in B02, with **Mark as not done** available instead of Mark done.

### 10. B10 — Plan's keyboard-dismiss button is sometimes missing

**Reported:** The keyboard on Plan sometimes lacks the keyboard-down/dismiss button.

**Expected:** The dismiss button is consistently available when the keyboard is shown on Plan.

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

### 12. B12 — Remove expiry-based thought thickness entirely

**Requested:** Remove the entire feature that changes a thought's thickness according to how
soon it will expire. Remove all code and artifacts for that feature and repair all affected
dependencies when implementation is authorized.

This request concerns the expiry-based **thickness treatment**; no broader removal of thought
expiration or archiving has been requested.

## Quality of life / UX

### 1. Q01 — Mark done looks like the action for saving edits

**Reported:** In a task thought's editor, **Mark done** is large and centrally placed. After
editing, a user may mistake it for the action that finishes and saves their edits.

**Requested:** Move or restyle the completion action so it is out of the way of the editing/save
flow, while remaining immediately discoverable when the user wants to complete the task.
It must be clearly distinguishable from saving edits. Exact design is deferred until permission.

## Report history

- **2026-10-08:** Recorded the initial 12 bugs/requested changes and one UX request, including
  the supplied sharing-error screenshots. Collection only; no investigation or fixes authorized.
