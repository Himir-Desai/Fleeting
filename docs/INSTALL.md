# Putting Fleeting on your phone

There is no App Store listing and no TestFlight. This is the other path: build the app on your Mac
and install it on your own iPhone, signed with your own free Apple ID. No Developer Program
membership, no fee, no review.

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
