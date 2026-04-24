import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: make-icon.swift /path/to/LatexcopIcon.icns")
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iconsetURL = outputURL.deletingLastPathComponent().appendingPathComponent("LatexcopIcon.iconset")
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let icons: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func renderIcon(pixels: Int, to url: URL) throws {
    let size = NSSize(width: pixels, height: pixels)
    let image = NSImage(size: size)
    image.lockFocus()

    let rect = NSRect(origin: .zero, size: size)
    let radius = CGFloat(pixels) * 0.22
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSColor(calibratedRed: 0.10, green: 0.14, blue: 0.18, alpha: 1).setFill()
    path.fill()

    let highlight = NSBezierPath(
        roundedRect: rect.insetBy(dx: CGFloat(pixels) * 0.08, dy: CGFloat(pixels) * 0.08),
        xRadius: radius * 0.72,
        yRadius: radius * 0.72
    )
    NSColor(calibratedWhite: 1, alpha: 0.08).setStroke()
    highlight.lineWidth = max(1, CGFloat(pixels) * 0.012)
    highlight.stroke()

    let emoji = "👮" as NSString
    let font = NSFont.systemFont(ofSize: CGFloat(pixels) * 0.62)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
    ]
    let emojiSize = emoji.size(withAttributes: attributes)
    let emojiRect = NSRect(
        x: (size.width - emojiSize.width) / 2,
        y: (size.height - emojiSize.height) / 2 + CGFloat(pixels) * 0.015,
        width: emojiSize.width,
        height: emojiSize.height
    )
    emoji.draw(in: emojiRect, withAttributes: attributes)

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to render icon")
    }
    try png.write(to: url)
}

for icon in icons {
    try renderIcon(pixels: icon.pixels, to: iconsetURL.appendingPathComponent(icon.name))
}

try? fileManager.removeItem(at: outputURL)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    fatalError("iconutil failed")
}

try? fileManager.removeItem(at: iconsetURL)
