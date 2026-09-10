import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Renders the app icon: the sprout, drawn at icon scale.
//
// The mark the app already uses for a kept habit and a saved thought (ADR-0042), so the icon is
// the product's own vocabulary rather than a separate piece of art. The geometry is a transcript
// of `SproutMark` — same stem curve, same two opposed leaves, same proportions — because an icon
// that merely resembled the in-app mark would drift from it at the first change (ADR-0049).
//
// Usage: `swift Tools/MakeIcon.swift <output.png> [light|dark]`
//
// Both appearances are rendered from this one path. The stroke is the accent read for that
// appearance, on that appearance's page colour, exactly as the app draws it.

/// One appearance's two colours, taken from `Palette`.
struct Appearance {
    let background: CGColor
    let stroke: CGColor

    /// The light appearance: the accent as text, on the warm paper.
    static let light = Appearance(
        background: CGColor(srgbRed: 0.976, green: 0.969, blue: 0.949, alpha: 1),
        stroke: CGColor(srgbRed: 0.29, green: 0.227, blue: 0.784, alpha: 1)
    )

    /// The dark appearance: the lighter accent, on the near-black page.
    static let dark = Appearance(
        background: CGColor(srgbRed: 0.043, green: 0.043, blue: 0.051, alpha: 1),
        stroke: CGColor(srgbRed: 0.56, green: 0.505, blue: 0.949, alpha: 1)
    )
}

let side = 1024
let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(
        Data("usage: MakeIcon.swift <output.png> [light|dark]\n".utf8)
    )
    exit(2)
}

let appearance = arguments.count >= 3 && arguments[2] == "dark" ? Appearance.dark : .light

let space = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: side,
    height: side,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

context.setFillColor(appearance.background)
context.fill(CGRect(x: 0, y: 0, width: side, height: side))

// The square the mark is drawn in, inset so the sprout sits inside the rounded mask iOS applies
// rather than running into its corners. Flipped in Y because Core Graphics puts the origin at the
// bottom while `SproutMark` is written in SwiftUI's top-left coordinates.
//
// `SproutMark` does not fill its own frame — the stem stops at 10% from the top and the leaves
// reach 16% and 90% across — so drawing it in a centred square leaves it visibly low and left.
// The used region is measured here and recentred, which is what makes the icon look centred
// rather than merely being centred.
let used = (minX: 0.16, maxX: 0.90, minY: 0.10, maxY: 1.00)
let box = CGRect(x: 0, y: 0, width: CGFloat(side), height: CGFloat(side)).insetBy(
    dx: CGFloat(side) * 0.20,
    dy: CGFloat(side) * 0.20
)
let usedWidth = used.maxX - used.minX
let usedHeight = used.maxY - used.minY
let scale = min(box.width / usedWidth, box.height / usedHeight)

/// Maps a `SproutMark` coordinate into the icon, recentred on the mark's own extent.
func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    let centredX = (x - used.minX - usedWidth / 2) * scale
    let centredY = (y - used.minY - usedHeight / 2) * scale
    return CGPoint(x: box.midX + centredX, y: box.midY - centredY)
}

/// The stem: one curve leaning slightly, so it reads as grown rather than ruled.
let stem = CGMutablePath()
stem.move(to: point(0.54, 1.00))
stem.addQuadCurve(to: point(0.46, 0.10), control: point(0.60, 0.50))

/// Two leaves, opposed and pointed. The right rises away from the stem; the left sits lower and
/// smaller, so the mark grows rather than mirrors.
let leaves = CGMutablePath()
leaves.move(to: point(0.50, 0.44))
leaves.addQuadCurve(to: point(0.90, 0.14), control: point(0.60, 0.18))
leaves.addQuadCurve(to: point(0.50, 0.44), control: point(0.80, 0.44))

leaves.move(to: point(0.50, 0.62))
leaves.addQuadCurve(to: point(0.16, 0.38), control: point(0.42, 0.40))
leaves.addQuadCurve(to: point(0.50, 0.62), control: point(0.24, 0.62))

// Heavier than the 1.5pt used in the app: at 1024 the same relative weight would be a hairline,
// and an icon has to read at 40pt on a home screen.
context.setStrokeColor(appearance.stroke)
context.setLineWidth(scale * 0.05)
context.setLineCap(.round)
context.setLineJoin(.round)
context.addPath(stem)
context.addPath(leaves)
context.strokePath()

guard let image = context.makeImage() else { exit(1) }
let url = URL(fileURLWithPath: arguments[1])
guard let destination = CGImageDestinationCreateWithURL(
    url as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else { exit(1) }
CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)
print("wrote \(url.path)")
