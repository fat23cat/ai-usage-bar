// Renders Resources/AppIcon.icns: three remaining-capacity bars in the
// Cardputer palette on a dark rounded square.
//
//   swift scripts/make_icon.swift Resources/AppIcon.icns
import AppKit
import Foundation

let output = CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.icns"
let fileManager = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("AppIcon-\(ProcessInfo.processInfo.processIdentifier).iconset")
try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

/// Draws on a 1024-point canvas, origin at the top left.
func draw(_ context: CGContext) {
    // macOS icon grid: an 824-point body centered on the 1024 canvas.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 10), blur: 28, color: color(0x000000, 0.35))
    context.addPath(shape)
    context.setFillColor(color(0x1F2430))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(shape)
    context.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [color(0x2C3344), color(0x161A22)] as CFArray,
                              locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: body.minY),
                               end: CGPoint(x: 0, y: body.maxY), options: [])
    context.restoreGState()

    let scale = body.width / 104
    let track = CGRect(x: body.minX + 20 * scale, y: 0, width: 64 * scale, height: 10 * scale)
    let bars: [(top: CGFloat, filled: CGFloat, color: UInt32)] = [
        (28, 50, 0x5DCAA5), // Leaf: plenty left
        (47, 30, 0x85B7EB), // Blue: moderate
        (66, 11, 0xF09595), // Vermilion: low
    ]
    let radius = track.height / 2
    for bar in bars {
        let row = track.offsetBy(dx: 0, dy: body.minY + bar.top * scale)
        context.addPath(CGPath(roundedRect: row, cornerWidth: radius, cornerHeight: radius,
                               transform: nil))
        context.setFillColor(color(0xFFFFFF, 0.14))
        context.fillPath()
        var fill = row
        fill.size.width = bar.filled * scale
        context.addPath(CGPath(roundedRect: fill, cornerWidth: radius, cornerHeight: radius,
                               transform: nil))
        context.setFillColor(color(bar.color))
        context.fillPath()
    }
}

func png(pixels: Int) throws -> Data {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw NSError(domain: "icon", code: 1) }
    let factor = CGFloat(pixels) / 1024
    context.translateBy(x: 0, y: CGFloat(pixels))
    context.scaleBy(x: factor, y: -factor)
    draw(context)
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    guard let data = bitmap.representation(using: .png, properties: [:])
    else { throw NSError(domain: "icon", code: 2) }
    return data
}

for points in [16, 32, 128, 256, 512] {
    try png(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(pixels: points * 2)
        .write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output]
try iconutil.run()
iconutil.waitUntilExit()
try? fileManager.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { exit(iconutil.terminationStatus) }
print("Wrote \(output)")
