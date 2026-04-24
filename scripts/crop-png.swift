import AppKit
import Foundation

guard CommandLine.arguments.count == 7 else {
    fatalError("Usage: crop-png.swift image.png x y width height output.png")
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let x = Int(CommandLine.arguments[2]),
      let y = Int(CommandLine.arguments[3]),
      let width = Int(CommandLine.arguments[4]),
      let height = Int(CommandLine.arguments[5]) else {
    fatalError("Crop coordinates must be integers")
}
let outputURL = URL(fileURLWithPath: CommandLine.arguments[6])

guard let image = NSImage(contentsOf: inputURL),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let cropped = cgImage.cropping(to: CGRect(x: x, y: y, width: width, height: height)) else {
    fatalError("Could not crop image: \(inputURL.path)")
}

let output = NSImage(cgImage: cropped, size: NSSize(width: width, height: height))
guard let tiff = output.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not write image: \(outputURL.path)")
}

try png.write(to: outputURL)
