import AppKit
import Foundation

guard CommandLine.arguments.count >= 3,
      let padding = Int(CommandLine.arguments[1]) else {
    fatalError("Usage: pad-png.swift padding image.png [...]")
}

for path in CommandLine.arguments.dropFirst(2) {
    let url = URL(fileURLWithPath: path)
    guard let image = NSImage(contentsOf: url),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("Could not read image: \(path)")
    }

    let width = cgImage.width + padding * 2
    let height = cgImage.height + padding * 2
    let output = NSImage(size: NSSize(width: width, height: height))

    output.lockFocus()
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    image.draw(
        in: NSRect(x: padding, y: padding, width: cgImage.width, height: cgImage.height),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    output.unlockFocus()

    guard let tiff = output.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not render image: \(path)")
    }

    try png.write(to: url)
}
