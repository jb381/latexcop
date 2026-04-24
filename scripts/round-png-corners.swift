import AppKit
import Foundation

guard CommandLine.arguments.count >= 2 else {
    fatalError("Usage: round-png-corners.swift image.png [...]")
}

let radiusRatio: CGFloat = 0.055

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    guard let image = NSImage(contentsOf: url),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("Could not read image: \(path)")
    }

    let width = cgImage.width
    let height = cgImage.height
    let size = NSSize(width: width, height: height)
    let radius = min(size.width, size.height) * radiusRatio
    let output = NSImage(size: size)

    output.lockFocus()
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()

    let rect = NSRect(origin: .zero, size: size)
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    image.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
    output.unlockFocus()

    guard let tiff = output.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not render image: \(path)")
    }

    try png.write(to: url)
}
