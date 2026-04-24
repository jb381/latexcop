import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: mask-popover-png.swift image.png")
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let image = NSImage(contentsOf: url),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("Could not read image: \(url.path)")
}

let width = cgImage.width
let height = cgImage.height
let size = NSSize(width: width, height: height)
let topInset: CGFloat = 12
let radius: CGFloat = 18
let notchWidth: CGFloat = 34

let output = NSImage(size: size)
output.lockFocus()
NSColor.clear.setFill()
NSRect(origin: .zero, size: size).fill()

let path = NSBezierPath(
    roundedRect: NSRect(x: 0, y: 0, width: size.width, height: size.height - topInset),
    xRadius: radius,
    yRadius: radius
)
let centerX = size.width / 2
path.move(to: NSPoint(x: centerX - notchWidth / 2, y: size.height - topInset))
path.line(to: NSPoint(x: centerX - 8, y: size.height - topInset))
path.curve(
    to: NSPoint(x: centerX, y: size.height),
    controlPoint1: NSPoint(x: centerX - 4, y: size.height - topInset),
    controlPoint2: NSPoint(x: centerX - 4, y: size.height)
)
path.curve(
    to: NSPoint(x: centerX + 8, y: size.height - topInset),
    controlPoint1: NSPoint(x: centerX + 4, y: size.height),
    controlPoint2: NSPoint(x: centerX + 4, y: size.height - topInset)
)
path.line(to: NSPoint(x: centerX + notchWidth / 2, y: size.height - topInset))
path.close()
path.addClip()

image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
output.unlockFocus()

guard let tiff = output.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render image: \(url.path)")
}

try png.write(to: url)
