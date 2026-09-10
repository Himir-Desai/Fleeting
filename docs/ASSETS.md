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
