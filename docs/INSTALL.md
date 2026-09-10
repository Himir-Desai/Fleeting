# Putting Fleeting on your phone

There is no App Store listing and no TestFlight. This is the other path: build the app on your Mac
and install it on your own iPhone, signed with your own free Apple ID. No Developer Program
membership, no fee, no review.

```bash
export DEVELOPMENT_TEAM=XXXXXXXXXX   # see "Finding your Team ID" below
Tools/install-device.sh
```

Then trust the signature **on the phone** — a free signature is not trusted until its owner says so:

> Settings ▸ General ▸ VPN & Device Management ▸ Apple Development: *your Apple ID* ▸ **Trust**

Open Fleeting from the home screen. That is the whole procedure.

---

## What you need

| | |
|---|---|
| **Xcode 26+** with the iOS 26 SDK | The app targets iOS 26 |
| **An Apple ID** | Free. Signed into Xcode ▸ Settings ▸ Accounts |
| **An iPhone running iOS 26+**, unlocked and plugged in | Tap Trust on the phone the first time |
| **XcodeGen** | `brew install xcodegen` |

## Finding your Team ID

Xcode ▸ Settings ▸ Accounts ▸ select your Apple ID. The team beneath it is labelled
**(Personal Team)**, and its ten-character ID is what `DEVELOPMENT_TEAM` wants. If no team is
listed, add your Apple ID with the **+** button first.

## What is different about a free-signed build

A personal team can sign an app and put it on its owner's device. What it cannot do is issue the
iCloud or App Group entitlements, and asking for an entitlement you cannot have does not degrade
gracefully — the provisioning profile simply refuses to generate. So the install script builds from
`project-personal.yml`, which strips both, and the app takes the fallback it was designed and
tested for from the start ([ADR-0019](DECISIONS.md)):

- **Your thoughts live on the phone and only on the phone.** Settings says *This iPhone only*
  rather than pretending to sync. Everything else in the app is unaffected.
- **The widget shows its placeholder.** It reads the shared store through the App Group, and
  without that entitlement it has nothing to read.
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

**"Unable to install"** or a profile error — the Apple ID is probably not in Xcode ▸ Settings ▸
Accounts, or `DEVELOPMENT_TEAM` is a different team from the one signed in. A free Apple ID is also
capped at **three** apps at a time; delete an older self-signed app if you have hit it.

**"Untrusted Developer" when opening the app** — the trust step above has not been done yet. It has
to happen on the phone, and only after the app is installed.

**The app launches and immediately quits, a week later** — the signature expired. Re-run the script.
