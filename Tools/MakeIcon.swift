import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Renders the app icon: three lines of a note, each shorter and fainter than the one above,
/// so the mark says "written down, and already going".
let side = 1024
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

// The app's dark surface, so the icon and a cold launch look like the same product.
context.setFillColor(CGColor(srgbRed: 0.04, green: 0.04, blue: 0.05, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: side, height: side))

let lines: [(width: CGFloat, alpha: CGFloat)] = [
    (700, 1.0),
    (530, 0.58),
    (360, 0.30)
]
let height: CGFloat = 120
let gap: CGFloat = 72
let totalHeight = CGFloat(lines.count) * height + CGFloat(lines.count - 1) * gap
let left: CGFloat = 162
var top = (CGFloat(side) + totalHeight) / 2 - height

for line in lines {
    context.setFillColor(CGColor(srgbRed: 0.56, green: 0.505, blue: 0.949, alpha: line.alpha))
    let rect = CGRect(x: left, y: top, width: line.width, height: height)
    context.addPath(CGPath(
        roundedRect: rect,
        cornerWidth: height / 2,
        cornerHeight: height / 2,
        transform: nil
    ))
    context.fillPath()
    top -= height + gap
}

guard let image = context.makeImage() else { exit(1) }
let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let destination = CGImageDestinationCreateWithURL(
    url as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else { exit(1) }
CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)
print("wrote \(url.path)")
