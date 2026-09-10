#!/usr/bin/env bash
#
# Builds Fleeting and installs it on a physical iPhone, signed with a free Apple ID.
#
# There is no App Store and no TestFlight in this path. A personal team can sign an app and put
# it on its owner's own device, which is exactly what is wanted here. What it cannot do is issue
# the iCloud or App Group entitlements, so this script builds from `project-personal.yml`, which
# strips both. The app has a tested fallback for precisely that case (ADR-0019): the store
# becomes device-local and Settings says "This iPhone only".
#
# The seven-day expiry is a property of the free tier, not of this script: a personal-team
# signature is good for a week, after which the app refuses to launch until it is installed
# again. Re-run this script.
#
# Usage:
#   Tools/install-device.sh              # build, sign, install on the one connected iPhone
#   Tools/install-device.sh --list       # just show what is connected
#
# Requires DEVELOPMENT_TEAM, the ten-character Team ID of the Apple ID signed into Xcode:
#   Xcode ▸ Settings ▸ Accounts ▸ (add your Apple ID) ▸ the team listed underneath.
#   export DEVELOPMENT_TEAM=XXXXXXXXXX
#
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="Fleeting-Personal.xcodeproj"
SCHEME="Fleeting"
BUNDLE_ID="com.himirdesai.Fleeting"

# `devicectl` reports every device it has ever paired. Only a connected one can be installed to.
list_devices() {
	xcrun devicectl list devices 2>/dev/null | grep -v "unavailable" || true
}

if [[ "${1:-}" == "--list" ]]; then
	echo "Devices visible to Xcode:"
	xcrun devicectl list devices
	exit 0
fi

# --- The Team ID ------------------------------------------------------------------------------
# Asked for rather than guessed. Signing with the wrong team produces a build that installs and
# then refuses to launch, which is a far more confusing failure than stopping here.

if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
	cat >&2 <<-'MESSAGE'
		error: DEVELOPMENT_TEAM is not set.

		This is the ten-character Team ID belonging to the Apple ID signed into Xcode.
		A free Apple ID has one; no paid membership is needed.

		  1. Xcode ▸ Settings ▸ Accounts
		  2. Add your Apple ID if it is not there
		  3. Select it — the team is listed below, ending in a (Personal Team) label
		  4. export DEVELOPMENT_TEAM=XXXXXXXXXX

		Then run this script again.
	MESSAGE
	exit 1
fi

# --- The device -------------------------------------------------------------------------------

DEVICE_ID="${DEVICE_ID:-}"
if [[ -z "$DEVICE_ID" ]]; then
	# The identifier is the UUID-shaped field on a connected device's line. `|| true` because no
	# match is the ordinary "nothing plugged in" case, which is reported below rather than by
	# `set -e` killing the script without a word.
	DEVICE_ID=$(list_devices | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1 || true)
fi

if [[ -z "$DEVICE_ID" ]]; then
	cat >&2 <<-'MESSAGE'
		error: no connected iPhone found.

		Plug the phone in with a cable, unlock it, and tap Trust if asked.
		Over Wi-Fi it must have been paired to this Mac at least once by cable.

		  Tools/install-device.sh --list    # to see what Xcode can see

		If the phone is listed but shows as unavailable, it is paired but not reachable:
		unlock it and check the cable.
	MESSAGE
	exit 1
fi

echo "▸ Device:  $DEVICE_ID"
echo "▸ Team:    $DEVELOPMENT_TEAM"

# --- Generate, build, install -----------------------------------------------------------------

echo "▸ Generating the personal-team project..."
xcodegen generate --spec project-personal.yml --project . >/dev/null

# Emptied here rather than in the spec: XcodeGen *merges* an included spec's entitlement
# properties rather than replacing them, so declaring an empty set in `project-personal.yml`
# silently inherits the very iCloud and App Group keys it is meant to strip. Written after
# generation, since generation is what recreates them.
for plist in App/Fleeting-personal.entitlements Widgets/FleetingWidgets-personal.entitlements; do
	cat >"$plist" <<-'EMPTY'
		<?xml version="1.0" encoding="UTF-8"?>
		<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
		<plist version="1.0">
		<dict/>
		</plist>
	EMPTY
done

# Asserted rather than assumed. A stray entitlement here is not a build error, it is a profile
# that will not generate, reported hundreds of lines into xcodebuild's output as something else.
for plist in App/Fleeting-personal.entitlements Widgets/FleetingWidgets-personal.entitlements; do
	if grep -q "icloud\|application-groups" "$plist"; then
		echo "error: $plist still requests an entitlement a personal team cannot issue." >&2
		exit 1
	fi
done

DERIVED="$(mktemp -d)/DerivedData"

echo "▸ Building (Release)..."
xcodebuild \
	-project "$PROJECT" \
	-scheme "$SCHEME" \
	-configuration Release \
	-destination "id=$DEVICE_ID" \
	-derivedDataPath "$DERIVED" \
	-allowProvisioningUpdates \
	DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
	CODE_SIGN_STYLE=Automatic \
	build \
	| grep -E "error:|warning: .*(signing|provisioning)|BUILD" || true

APP="$DERIVED/Build/Products/Release-iphoneos/Fleeting.app"
if [[ ! -d "$APP" ]]; then
	echo "error: the build produced no app. Run the xcodebuild command above without the grep to see why." >&2
	exit 1
fi

echo "▸ Installing..."
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"

cat <<-MESSAGE

	Installed.

	One thing left, and it must be done on the phone: a free signature is not trusted
	until its owner says so.

	  Settings ▸ General ▸ VPN & Device Management ▸ Apple Development: <your Apple ID> ▸ Trust

	Then open Fleeting from the home screen.

	This signature expires in seven days, which is the free tier's limit rather than
	the app's. Run this script again to renew it; your thoughts are not touched.
MESSAGE
