#!/usr/bin/env python3
"""Reject a distribution IPA that lost Fleeting's sync/widget capabilities."""

import plistlib
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

TEAM = "23C785D8QZ"
BUNDLE = "com.himirdesai.Fleeting"
GROUP = "group.com.himirdesai.Fleeting"
CONTAINER = "iCloud.com.himirdesai.Fleeting"


def check_bundle(bundle, identifier):
    result = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(bundle)],
        capture_output=True,
        check=True,
    )
    entitlements = plistlib.loads(result.stdout)
    required = {
        "application-identifier": f"{TEAM}.{identifier}",
        "com.apple.developer.team-identifier": TEAM,
        "com.apple.security.application-groups": [GROUP],
        "get-task-allow": False,
        "beta-reports-active": True,
    }
    if identifier == BUNDLE:
        required.update({
            "com.apple.developer.icloud-container-identifiers": [CONTAINER],
            "com.apple.developer.icloud-services": ["CloudKit"],
            "com.apple.developer.icloud-container-environment": "Production",
            "com.apple.developer.ubiquity-kvstore-identifier": f"{TEAM}.{BUNDLE}",
            "aps-environment": "production",
        })
    for key, expected in required.items():
        if entitlements.get(key) != expected:
            raise ValueError(f"{identifier}: missing or incorrect {key}")
    subprocess.run(
        ["codesign", "--verify", "--strict", str(bundle)],
        capture_output=True,
        check=True,
    )
    info = plistlib.loads((bundle / "Info.plist").read_bytes())
    print(f"Verified {identifier} {info['CFBundleShortVersionString']} ({info['CFBundleVersion']})")
    return info


def main():
    if len(sys.argv) != 2:
        raise ValueError("Usage: python3 Tools/verify-distribution.py Fleeting.ipa")
    with tempfile.TemporaryDirectory(prefix="fleeting-distribution-") as directory:
        with zipfile.ZipFile(sys.argv[1]) as package:
            package.extractall(directory)
        app = Path(directory) / "Payload/Fleeting.app"
        info = check_bundle(app, BUNDLE)
        widget = check_bundle(app / "PlugIns/FleetingWidgets.appex", f"{BUNDLE}.Widgets")
        if info["CFBundleVersion"] != widget["CFBundleVersion"]:
            raise ValueError("App and widget build numbers differ")
        if info.get("CKSharingSupported") is not True:
            raise ValueError("CloudKit invitation handling is disabled")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError, plistlib.InvalidFileException) as error:
        sys.exit(f"Distribution verification failed: {error}")
