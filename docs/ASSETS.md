# Generated assets

## App icon

The icon is rendered from code rather than drawn, so it can be regenerated at any size and its
colours stay in step with the palette. It is the sprout — the same mark the app draws for a kept
habit and a saved thought — so the first thing anyone sees is the product's own vocabulary
(ADR-0049).

Both appearances are generated, and both are needed: the light one and the dark one, each in that
appearance's accent on that appearance's page colour.

```bash
swift Tools/MakeIcon.swift App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
swift Tools/MakeIcon.swift App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024-dark.png dark
```

The script uses only CoreGraphics and ImageIO, so it needs no toolchain beyond Xcode. Colours are
transcribed from `Palette` — `surface` and `accentText`, in each appearance — and the geometry is a
transcript of `SproutMark`. A standalone script cannot import DesignSystem, so if either the palette
or the sprout's shape changes, the icon is stale until it is regenerated and compared by eye.

## Screenshots

The current README uses **v2.1** assets in `docs/screenshots/v2.1/`. The light and dark directories
contain actual app captures from the accepted v2.1 source, collected on 2026-10-17 with the iOS 27
**Fleeting v2.1 Regression** simulator. DEBUG demo/Plan seeds and synthetic custom-list records
provide the content. No owner data or live sharing participants are used.

- `DesignAuditTests/testAllDestinations` captures Home, Thoughts, thought properties/actions,
  Sharpen, thought review, Plan, daily review, Settings/about, and the list manager.
- `ScreenshotTests/testCaptureV21ListsAndRestoreScreenshots` captures Home after custom-list capture,
  the Lists popover, a custom list's top-level share control, its editor, an archived thought's
  Unarchive control, and a completed task's Mark not done control.
- `review-source-lists.png` retains the 2026-10-15 cross-list review-context capture from
  `ThoughtReviewTests/testReviewFromOneListShowsNamedAndUnfiledSources`. That app UI is unchanged
  in the accepted build. It demonstrates the named-list caption in a global session.
- `large-text-task-actions.png` retains the 2026-10-15 largest-text capture from
  `V21RegressionTests/testCompletedTaskActionsStayInOneScrollableRowAtLargestText`. The horizontal
  action row and its labels are unchanged in the accepted build.

Earlier screenshot directories are historical evidence, not the current README source. Images
are copied directly from XCTest PNG attachments, with no retouching or generated UI. All current
captures are visually checked before committing. Fresh standard-size captures use a 9:41 status
bar; older refinement captures retain their original status bar.

### Reproduce the app tours

Choose a **dedicated disposable simulator** first. The tests pass `--reset-store` and deliberately
replace that simulator's app data. Never target the owner's signed-in simulator or a device with
records to keep. Use its UUID rather than a potentially ambiguous device name.

From the repository root (the result directories must be new for each run):

```bash
export FLEETING_DOCS_SIM="<disposable-simulator-uuid>"
xcrun simctl boot "$FLEETING_DOCS_SIM"
xcrun simctl bootstatus "$FLEETING_DOCS_SIM" -b
xcrun simctl status_bar "$FLEETING_DOCS_SIM" override --time '9:41' \
  --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100

xcrun simctl ui "$FLEETING_DOCS_SIM" appearance light
xcodebuild test -project Fleeting.xcodeproj -scheme Fleeting \
  -destination "platform=iOS Simulator,id=$FLEETING_DOCS_SIM" \
  -parallel-testing-enabled NO \
  -only-testing:FleetingUITests/DesignAuditTests/testAllDestinations \
  -only-testing:FleetingUITests/ScreenshotTests/testCaptureV21ListsAndRestoreScreenshots \
  -resultBundlePath /tmp/fleeting-v21-light.xcresult

xcrun simctl ui "$FLEETING_DOCS_SIM" appearance dark
xcodebuild test -project Fleeting.xcodeproj -scheme Fleeting \
  -destination "platform=iOS Simulator,id=$FLEETING_DOCS_SIM" \
  -parallel-testing-enabled NO \
  -only-testing:FleetingUITests/DesignAuditTests/testAllDestinations \
  -only-testing:FleetingUITests/ScreenshotTests/testCaptureV21ListsAndRestoreScreenshots \
  -resultBundlePath /tmp/fleeting-v21-dark.xcresult

xcrun xcresulttool export attachments --path /tmp/fleeting-v21-light.xcresult \
  --output-path /tmp/fleeting-v21-light-images
xcrun xcresulttool export attachments --path /tmp/fleeting-v21-dark.xcresult \
  --output-path /tmp/fleeting-v21-dark-images
```

Run only these selected screenshot cases, not the entire UI suite. If the isolated simulator is
already booted, skip the boot command. Finish by shutting down that same isolated simulator.

### Name the exported attachments

`xcresulttool` supplies a `manifest.json` mapping attachment names to PNG files. The numbered
names below are the tour's destinations, rather than screenshot timestamps or incidental XCTest
failure snapshots. This copies the original bytes into the documentation directory:

```python
import json
import shutil
from pathlib import Path

names = {
    "01 Home with habits": "01-home",
    "02 Thoughts": "02-thoughts",
    "03 Thought properties": "03-thought-properties",
    "04 Thought actions": "04-thought-actions",
    "05 Sharpened thought": "05-sharpened-thought",
    "06 Sharpen actions": "06-sharpen-actions",
    "07 Thought review": "07-thought-review",
    "08 Plan": "08-plan",
    "09 Daily review": "09-daily-review",
    "10 Settings": "10-settings",
    "11 Settings about": "11-settings-about",
    "12 Lists": "12-list-manager",
    "Home selected list": "home-selected-list",
    "Lists picker": "lists-picker",
    "Selected list": "selected-list",
    "List editor": "list-editor",
    "Archived thought": "archived-thought",
    "Completed task": "completed-task",
}
for appearance in ("light", "dark"):
    source = Path(f"/tmp/fleeting-v21-{appearance}-images")
    destination = Path(f"docs/screenshots/v2.1/{appearance}")
    destination.mkdir(parents=True, exist_ok=True)
    for test in json.loads((source / "manifest.json").read_text()):
        for attachment in test["attachments"]:
            title = attachment["suggestedHumanReadableName"].split("_0_")[0]
            if title in names and not attachment["isAssociatedWithFailure"]:
                shutil.copy2(
                    source / attachment["exportedFileName"],
                    destination / (names[title] + ".png"),
                )
```

Inspect every exported destination and both appearances, then check the README's image paths
and captions. Screenshot generation validates the reached UI states; it does not establish live
CloudKit invitation delivery or widget behavior on a phone. The full asset folder is intentionally
kept alongside the subset embedded in the README.
