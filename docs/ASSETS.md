# Generated assets

## App icon

The icon is rendered from code rather than drawn, so it can be regenerated at any size and its
colours stay in step with the palette. Three lines of a note, each shorter and fainter than the one
above it: written down, and already going.

```bash
swift Tools/MakeIcon.swift App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
```

The script uses only CoreGraphics and ImageIO, so it needs no toolchain beyond Xcode. Colours come
from `Palette.surfaceValues.dark` and `Palette.accentTextValues.dark`; if either changes, rerun it.

## Screenshots

`docs/screenshots/*.png` are produced by `ScreenshotTests` in the UI suite, not taken by hand, so
the screens they show are ones the tests still drive. To regenerate:

```bash
xcodebuild test -project Fleeting.xcodeproj -scheme Fleeting \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:FleetingUITests/ScreenshotTests \
  -resultBundlePath /tmp/shots.xcresult CODE_SIGNING_ALLOWED=NO
```

Then pull the attachments out of the result bundle with `xcrun xcresulttool` and copy them into
`docs/screenshots/`.
