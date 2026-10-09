# iCloud saving and shared lists for Fleeting 2.0

Use the regular `Fleeting.xcodeproj` and paid team `23C785D8QZ`. The personal-team
overlay intentionally strips capabilities and cannot sync. Do not uninstall the old app to
upgrade: installing over it retains local records for the one-time App Group import.

## Apple setup

1. In Signing & Capabilities, verify iCloud / CloudKit uses `iCloud.com.himirdesai.Fleeting`,
   App Groups uses `group.com.himirdesai.Fleeting`, and Push Notifications is enabled for the app.
   Key-value storage uses `$(TeamIdentifierPrefix)com.himirdesai.Fleeting`.
   The checked-in spec includes these entitlements and background remote notifications.
2. Use automatic signing with the paid team and regenerate provisioning profiles if Xcode reports
   missing entitlements. Distribution signing selects the production push environment.
3. For a signed **Debug development-environment build only**, add
   `--initialize-cloudkit-schema` to Run → Arguments in Xcode and run once. Check the CloudSchema
   log for success, then remove the argument. This explicit developer tool creates schema fixtures;
   it never runs in normal launches or Release/TestFlight. Apple's initializer must not be run
   against Production. V8 adds the optional ThoughtEntity ↔ ThoughtListEntity relationship,
   sharingEnabled and MemberActivityEntity (including updatedAt) to the prior V7 metadata/defaults.
   In CloudKit Console, inspect these model fields/types and deploy the schema to Production
   before TestFlight or App Store verification. No second container or public database is used.
   Development and production records are separate; compare installs using the same environment.
4. Same-account sync uses the same Apple Account on both devices. Cross-account sharing uses
   different Apple Accounts (see the sharing checklist below), with iCloud enabled for Fleeting.
   Do not use `--reset-store` or demo launch arguments for signed acceptance.

## What follows the account

- Captured thoughts and text edits, type/title, dates, lifetimes and cadence.
- Custom list names and membership; deleting a list keeps and unfiles its thoughts.
- Plan tasks and scheduling, completion, snoozing, archive state and explicit deletion.
- Habit streaks, saved Sharpen questions/answers and write-ups.
- Sorting preference, decay profiles, reminder preferences and capture-hint dismissal.

Unsubmitted capture/Sharpen drafts and navigation state are not saved records. Notification grants
and notification delivery history stay local. Sync propagates deletions and is not backup history.
No custom sign-in screen is required.

## Two-device acceptance

Use a signed build on two devices, preferably the same TestFlight build after schema deployment.
Keep the apps open initially; delivery timing is controlled by iCloud, not an immediate-save promise.

1. On A, create an idea, dated task and habit; verify each arrives on B without restarting.
2. On B, edit text, reschedule/complete the task, keep the habit, and save a Sharpen answer/write-up.
   Verify A's Thoughts, Plan, Home and Review reflect the updates. Check completed/archived records.
3. Keep a detail open on A; edit it on B. Verify A refreshes, while any unsaved text on A is preserved.
   Delete the record on B and verify the detail on A closes and lists remove it.
4. Change sorting, lifetimes and reminder preferences; verify the other device's Settings refreshes
   and the new decay rates apply. Each device must grant its own notification permission.
5. Disconnect A, create/edit items, relaunch while offline, and reconnect. Verify local saves survive
   and both devices converge. Repeat with different records edited on both devices offline.
6. Edit the same record on both devices offline and reconnect; check coherent lifecycle/streak
   values. CloudKit chooses merged values; the app does not promise to retain both edits as history.
7. Background B, edit on A, and reopen B. Check refreshed screens and widget timelines (widget
   refresh timing is controlled by iOS). Test notification-disabled devices too; silent sync must
   not require permission for user-visible alerts.
8. Upgrade a free-account install containing local data without uninstalling. Verify old and new
   records survive, sync, and deleted imported records do not return after relaunch.
9. With iCloud unavailable, verify capture still works and Settings explains local-only storage.
10. Create a custom list on A and capture into it. Verify its name and thought arrive on B, rename
    it on B, and move the thought to another list. Check both selectors refresh on A. Delete the
    custom list and verify its remaining thoughts survive in All thoughts on both devices.
    Capture explicitly into Plan and confirm it appears in the dated checklist on both devices.

Settings' “iCloud enabled” confirms configuration/account availability, not successful delivery of
every record. For failures, inspect device logs for the Fleeting Storage/Sync categories and Core
Data CloudKit errors, entitlement/provisioning mismatches, and missing production schema.

Implementation references: [Apple SwiftData sync](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
and [CloudKit diagnostics](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer).


## Cross-account shared-list acceptance

This is release acceptance, not an unsigned simulator test. Install the same signed build in the
same CloudKit environment on two devices with **different** iCloud accounts and Fleeting enabled.
The shared scope uses the existing container; CKSharingSupported is enabled in the app's Info.plist.
Upgrade every device on the owner's account to the sharing-capable build before sharing: older
clients do not understand private activity or manual archiving for shared content.

1. Upgrade A in place from V7 with private thoughts, Plan history, lists and habit streaks. Confirm
   every ID/content/date/metadata value survives. The original private SQLite store is retained;
   a journal-aware Fleeting-before-sharing.store recovery snapshot precedes the schema upgrade.
2. Create a custom list with a habit, idea, completed/archived thought and to-do. Give the habit
   a private streak and hide a thought before sharing. Tap its direct editor → Share List.
   Confirm native invited-only access, choose Can make changes, and send an invitation by Messages
   or copy the link. Verify AirDrop on physical devices where the system offers it.
3. Accept on B while Fleeting is closed, then while it is already running for another invitation.
   Verify the system launches the app and the *invited* list is selected after its zone imports,
   even when B already has other shared lists. Allow eventual import; no instant-sync promise.
4. Check shared metadata, original content and archived/completed history on B. A's private
   habit streak, hiding dates, reminder settings and attention must not appear as B's activity.
   Unrelated private lists and Plan must not appear at all.
5. Add/edit a thought from B, classify/correct its type, edit the list description/default and
   complete/undo a to-do. Verify A converges. Manually archive/restore and explicitly delete a
   thought; verify all members see those changes. Shared content must not auto-archive under
   either user's private decay settings.
6. Keep a habit and hide another thought on B. Check these affect only B's personal view and sync
   to B's own same-account device, while A's streak/visibility remains unchanged. Repeat on A.
7. Change B to view-only through Manage Sharing on A. After permission import, confirm B cannot
   edit list fields/content/type/cadence, add/delete/complete/archive shared thoughts, or use
   sharpening; it can still mark/undo its own habit progress and hide thoughts. Its capture text
   must remain intact if it attempts a write into a view-only destination.
8. Disconnect both devices, edit different records as editors and mark personal progress; relaunch
   offline and reconnect. Verify persisted caches and convergence. Edit the same record offline
   too; native per-column merging keeps lifecycle/streak payloads coherent without promising edit
   history or real-time synchronization.
9. Check that Manage Sharing on a viewer opens participant/leave controls. Have B leave; its
   shared graph disappears and A keeps its owned list. Remove a participant/stop sharing on A and
   verify revoked devices lose the shared content, UI refreshes, and the owner's content/history
   remains. Re-share after stopping. Verify owner-delete requires stopping sharing first and
   private-list deletion still unfiles thoughts. Plan has no share/edit/delete action.
10. Exercise optional Anyone with the link and Can view modes; only explicitly selected access
    expands beyond invited participants. Invalid/revoked links produce a useful system/app error.
    Cross-share moves are rejected without changing content. Network delays permit retry without
    erasing the owner's private progress or creating a second share for an already shared list.

If cloud attachment fails, local private capture continues. Imported participant lists are
conservatively view-only until cloud configuration is restored. An iCloud sign-out may remove
system-managed shared data; offline access describes the retained cache, not indefinite access
after leaving, revocation or sign-out. iCloud drives delivery and owns links; Fleeting hosts no server.

Local verification lives in CollaborationStoreTests, the isolated SchemaMigrationTests, Core
manual-archive tests and feature permission/draft tests. SharingTests checks native entry points,
local fallback/relaunch and viewer controls using DEBUG-only shared-store preview rows. It does
**not** deliver a live invitation. Production schema deployment is complete; cross-account
invitation/device checks remain pending.

References: [Apple Core Data sharing](https://developer.apple.com/documentation/coredata/sharing-core-data-objects-between-icloud-users),
[UICloudSharingController](https://developer.apple.com/documentation/uikit/uicloudsharingcontroller),
[SwiftUI scene delegates](https://developer.apple.com/documentation/swiftui/uiapplicationdelegateadaptor).


## Development schema initialization · 2026-10-07

Completed on the iPhone 17 Pro simulator after the user signed into iCloud. A CloudKit-enabled
Debug build was installed without resetting app data and launched once with
`--initialize-cloudkit-schema`. The Core Data private-store schema request finished at
00:41:25 America/Los_Angeles with `success: 1`, `madeChanges: 1`, and no error. The CloudKit
container proxy and private/shared subscriptions reported `environment=Sandbox`, confirming the
development environment. The shared-store initialization request was skipped by Apple because
shared scopes do not create schema; both stores use the same managed-object model. The app reported
successful development initialization and was relaunched without the one-time argument.

This confirms account connectivity and model/schema creation, not cross-account collaboration.
Production schema promotion and signed invitation/permission checks remain pending. Do not infer
container environment from the scheduler's `:Production` label alone; inspect the actual container
proxy/subscription environment and the Console environment instead.


## Production deployment · 2026-10-08

CloudKit Console's Confirm Deployment preview for iCloud.com.himirdesai.Fleeting was reviewed.
It proposes creating CD_DailyTodoEntity, CD_MemberActivityEntity, CD_ThoughtEntity and
CD_ThoughtListEntity. Index groups contain 12, 25, 62 and 19 additions respectively (118 total).
The preview also lists modifications to the generated _world, _icloud and _creator roles.
The preview lists all four types as creations, rather than merely additions to existing production
entity types. The generated role diff grants creator write, authenticated-user create and world
read for the public database. Fleeting uses private/shared databases for its content.

Deployment completed: CloudKit Console displayed **Changes Deployed — The schema is deployed to
Production**, and the schema links no longer carry Modified markers. The first Deploy click
completed asynchronously; a redundant retry was rejected by automatic approval review for
permanent definitions/public-role permissions. No workaround or subsequent Deploy action was used.
Version 2.0 build 3 is installed on the user's phone. Actual invitation acceptance and edits between
two separate iCloud accounts remain unverified.

### Distribution entitlement correction · 2026-10-08

Build 3 lacked signed App Group/CloudKit entitlements despite successful upload. The fault was the
unsigned archive used as a signing fallback, not the production schema. Build 4 uses a normally
signed archive and explicitly exports the Production iCloud environment. Both the local export
and exact staged upload IPA passed the new distribution verifier for app and widget. Do not
uninstall build 3 before updating; the existing local-store import preserves its captured thoughts.
