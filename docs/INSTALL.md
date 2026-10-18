# Putting Fleeting on your phone

The regular `Fleeting.xcodeproj` is committed for paid-team builds and Xcode Cloud. Select the
shared **Fleeting** scheme, Xcode 27 or later, and `main` as the cloud workflow branch. Its archive
action uses Release. The checked-in team matches the paid team selected in Xcode. Keep signing
settings in `project.yml` so regeneration preserves them.

For TestFlight, archive and upload through App Store Connect, then configure testers there.
The app and widget must use the same version/build numbers. A cloud archive and TestFlight upload
still need validation with Apple signing.

The instructions below are the alternative free-team route: build on your Mac and install on your
own iPhone, signed with a free Apple ID. No Developer Program membership, fee or review is needed.

```bash
Tools/install-device.sh
```

It finds your phone and your Team ID by itself. First time only, Xcode needs to have made you a
signing certificate — see [First time only](#first-time-only) below.

Then trust the signature **on the phone** — a free signature is not trusted until its owner says so:

> Settings ▸ General ▸ VPN & Device Management ▸ Apple Development: *your Apple ID* ▸ **Trust**

Open Fleeting from the home screen. That is the whole procedure.

---

## What you need

| | |
|---|---|
| **Xcode 27+** with the iOS 27 SDK | The app still runs on iOS 26+ |
| **An Apple ID** | Free. Signed into Xcode ▸ Settings ▸ Accounts |
| **Developer Mode** on the phone | Settings ▸ Privacy & Security ▸ Developer Mode |
| **An iPhone running iOS 26+**, unlocked and plugged in | Tap Trust on the phone the first time |
| **XcodeGen** | `brew install xcodegen` |

## First time only

Two things have to exist before the script can work, and both are one-time:

**1. A signing certificate.** Xcode ▸ Settings ▸ Accounts ▸ add your Apple ID ▸ select it ▸
**Personal Team** ▸ **Manage Certificates…** ▸ **+** ▸ **Apple Development** ▸ Done.

The script reads your Team ID out of that certificate, so nothing needs to be typed or exported.
(If you are curious: the ID is the certificate's `OU` field. The one shown in its name —
`Apple Development: you@example.com (XXXXXXXXXX)` — is a *different* identifier, and passing it
to `xcodebuild` produces a confident, entirely misleading "No Account for Team" error.)

**2. Developer Mode on the phone.** Settings ▸ Privacy & Security ▸ **Developer Mode** ▸ On, then
Restart. The option only appears in Settings once a Mac has tried to use the phone for development,
so if you cannot see it, run the script once and look again.

## What is different about a free-signed build

A personal team can sign an app and put it on its owner's device. What it cannot do is issue the
iCloud or App Group entitlements, and asking for an entitlement you cannot have does not degrade
gracefully — the provisioning profile simply refuses to generate. So the install script builds from
`project-personal.yml`, which strips both, and the app takes the fallback it was designed and
tested for from the start ([ADR-0019](DECISIONS.md)):

- **Your thoughts live on the phone and only on the phone.** Settings says *This iPhone only*
  rather than pretending to sync. Everything else in the app is unaffected.
- **The thoughts widget cannot show your notes.** It needs the shared App Group, which this
  build does not have. It explains that limitation and offers a tap to capture instead of
  displaying a misleading zero count. Capture shortcuts still work without shared storage.
- **Plan works inside the app.** Its Today and Tomorrow widgets also require shared storage to
  show or complete checklist tasks. Without it they explain the limitation and open Plan.
- **Everything else works**: capture, decay, classification, sharpening, review, the daily nudge,
  the URL scheme, Siri.

Nothing is stubbed out for this build. It is the same code taking a branch it already had.

### The seven-day clock

A free signature is valid for **seven days**. On the eighth the app refuses to launch until it is
signed again. Re-run `Tools/install-device.sh`; it reinstalls over the top and **your thoughts are
not touched**, because the data lives in the app's container rather than in the signature.

This is a limit of the free tier, not of the app. A paid membership extends it to a year and
restores iCloud and the widget, at which point the ordinary `project.yml` is the one to build.

## When it goes wrong

**"no connected iPhone found"** — plug the phone in with a cable, unlock it, tap Trust if asked.
`Tools/install-device.sh --list` shows what Xcode can see. A device listed as *unavailable* is
paired but not reachable right now.

**"Developer Mode is disabled"** — see step 2 above. If it was already on, the phone has probably
just locked; unlock it and run the script again.

**"No Account for Team"** — the Team ID is wrong. Delete the certificate and remake it as in step 1,
or override for one run with `DEVELOPMENT_TEAM=XXXXXXXXXX Tools/install-device.sh`.

**"Unable to install"** or a profile error — the Apple ID is probably not in Xcode ▸ Settings ▸
Accounts. A free Apple ID is also capped at **three** apps at a time; delete an older self-signed
app if you have hit it.

**"Untrusted Developer" when opening the app** — the trust step above has not been done yet. It has
to happen on the phone, and only after the app is installed.

**The app launches and immediately quits, a week later** — the signature expired. Re-run the script.


## Alpha-only TestFlight release · 2026-10-08

The user confirmed that the Internal “Tester Group” is the alpha audience; the External
“Tester Group” is the beta audience. Version 2.0 build 3 was archived from the current workspace
and successfully uploaded to App Store Connect with `testFlightInternalTestingOnly=true`.
This Apple-enforced marker prevents external TestFlight/App Store distribution of this build.
A later beta/public release requires a separate eligible upload. No external group was modified.

The user confirmed installation of the new version on their phone. App Store Connect's Internal
group explicitly shows **Build 2.0 (3) Internal — Testing** (90-day expiry). The Internal Only
upload restriction protects the external audience regardless of group assignment. Local archive signing initially
failed with errSecInternalComponent; an unsigned archive was completed and Xcode's automatic
App Store Connect exporter handled distribution signing/upload successfully. No repeat tests
were needed because the existing package and focused UI validation covered this source version.

Final audience verification: the External group's Builds tab contains only **1.0.0 (1) — Testing**;
2.0 (3) is absent. The owner's installed-version status can show 2.0 (3) in both tester views because
the owner belongs to both groups; group build assignment confirms the release audience.

### Build 4 correction

Build 3's unsigned-archive fallback was incorrect: Xcode's exporter signed it successfully but
did not restore the missing iCloud/App Group capabilities. The distribution pipeline's final
entitlements contained only basic application/team/TestFlight keys, explaining the device-local
sync warning. Do not ship an unsigned archive as a signing workaround.

Version 2.0 build 4 was archived with normal signing. A local distribution export and the exact
IPA staged for upload passed `python3 Tools/verify-distribution.py <IPA>`: app/widget signatures,
App Group access, CloudKit container/services, Production environment, production push,
key-value storage, matching build numbers and invitation support. The check also rejected build 3.
Both exports retain TestFlight Internal Only. Upload succeeded at 18:50 America/Los_Angeles;
App Store Connect finished processing and confirms build 4's only assigned group is the Internal
Tester Group (two testers). External distribution remains prohibited by Internal Only signing.
The Internal group's tester view subsequently reports the owner's phone as Installed 2.0 (4).
The testing note was saved with update-in-place and cross-account sharing instructions.

Update through TestFlight without uninstalling: capture in build 3 used the app's local support
store, and the existing local-to-App-Group migration preserves it when capabilities return.
This fixes the demonstrated signing omission; live invitation acceptance still needs a second
iCloud account. Package/UI source behavior is unchanged, so existing source tests were not rerun.

## v2.1 alpha release · 2026-10-15

The user authorized publishing the completed v2.1 fixes to the existing internal alpha testers.
The app and widget are version **2.1 (5)**. The release includes the completed-task action-row
correction and global review source-list context; see [BUGS_V2.1.md](BUGS_V2.1.md) for the scoped
changes, validation and remaining live-device acceptance checks.

Use a normally signed Release archive, Production CloudKit export and
`testFlightInternalTestingOnly=true`. Keep `manageAppVersionAndBuildNumber=false` so the verified
build number is preserved. The app declares `ITSAppUsesNonExemptEncryption=false`: it has no
custom encryption implementation or third-party cryptography and relies on Apple's operating
system for CloudKit security. This release metadata avoids a repeated missing-compliance gate.

Archive: `/tmp/Fleeting-2.1-5-alpha.xcarchive`. Local export:
`/tmp/fleeting21-alpha-export/Fleeting.ipa`. Both the final local IPA and the exact IPA staged by
the upload exporter pass `Tools/verify-distribution.py` for app/widget signatures and all required
capabilities. Both contain the expected 2.1 (5) version; the main app's encryption declaration is
verified. The upload uses the same Internal Only and Production export options.

**Upload succeeded at 19:54 local time on 2026-10-15** and Apple acknowledged that the package is
processing. Source release commit: `38ab961`. A copy of the verified upload-staged package is
retained at `/tmp/fleeting21-alpha-upload/Fleeting-uploaded.ipa`, SHA-256
`c4560c4803aa53ea24b58de8884e0ded95b1869e83d5bb1219e6442c03c8a8e8`.
Upload log: `/tmp/fleeting21-alpha-upload.log`.

Final processing and Internal Tester Group assignment are still unverified. After permissions
were enabled, the computer helper stopped reporting its startup error, but this session has no
connected browser and native-app APIs are unavailable. Connect the signed-in App Store Connect
browser, then verify 2.1 (5) is Testing in the existing **Internal → Tester Group**. Add the build
there if automatic distribution did not do so; preserve the External group. Prepared What to Test
text is at `/tmp/fleeting21-alpha-what-to-test.txt`. Do not describe alpha availability as verified
until this final check is complete.

## v2.1 external beta release · 2026-10-15

The user subsequently authorized distribution to the existing **External → Tester Group** as
well. Build 5's Internal Only restriction cannot be removed from that uploaded build. Prepare
version **2.1 (6)** from the same validated app source, with a normally signed Release archive,
Production CloudKit and `testFlightInternalTestingOnly=false`. Keep the build number fixed during
export. This is a TestFlight beta release; public App Store submission is outside this request.

**Upload succeeded on 2026-10-16**, and Apple acknowledged that the package is processing.
Source release commit: `987db0c`. Both the local export and exact upload-staged IPA pass
`Tools/verify-distribution.py`, including app/widget signatures, Production CloudKit and App Group
capabilities. The 2.1 (6) versions, encryption declaration and external-eligible export option were
also checked. The unchanged app implementation retains its existing source-test validation; no
repeat source test run was needed for the build-number/export-option change.

Archive: `/tmp/Fleeting-2.1-6-beta.xcarchive`. Local export:
`/tmp/fleeting21-beta-export/Fleeting.ipa`. Exact upload-staged package copy:
`/tmp/fleeting21-beta-upload/Fleeting-uploaded.ipa`, SHA-256
`a88a6794b39019b925129b479b99db40b1f2afefe9535d691eac7222590de772`.
Upload log: `/tmp/fleeting21-beta-upload.log`. Prepared What to Test text:
`/tmp/fleeting21-beta-what-to-test.txt`.

**External distribution is not completed.** The browser inventory remains empty and binding
App Store Connect returns `No browser is available`, including after the user's connection retry
and a fresh helper session. An App Store Connect API credential is not available to this task; the saved Xcode account
successfully uploads but does not provide group/review management through the export command.
Final processing, external-group assignment, review submission and tester availability remain
unverified. No external group or tester/public-link settings have been changed yet.

To finish in the connected browser or manually:

1. App Store Connect → Fleeting → TestFlight → **External Testing → Tester Group**.
2. Add Builds → choose **2.1 (6)** once processing finishes.
3. Use the prepared What to Test notes and select **Automatically notify testers**.
4. Choose **Submit Review** or **Start Testing**, as Apple offers. Reuse the existing review
   contact information. Confirm the group lists build 6 as Waiting for Review/In Review or Testing;
   only Testing establishes that the external release is available.

This handoff is required by the unavailable browser connection, not another approval requirement.
The user has already authorized external beta publication and its necessary review submission.
