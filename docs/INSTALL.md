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
