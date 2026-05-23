import AppKit

let size: CGFloat = 1024
let rect = NSRect(x: 0, y: 0, width: size, height: size)

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    fatalError("Failed to get graphics context")
}

ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)

// Clean single background gradient + soft radial lift.
let space = CGColorSpaceCreateDeviceRGB()
let colors = [
    CGColor(red: 0.03, green: 0.36, blue: 0.93, alpha: 1.0),
    CGColor(red: 0.10, green: 0.66, blue: 1.0, alpha: 1.0),
] as CFArray
let locations: [CGFloat] = [0.0, 1.0]
guard let linear = CGGradient(colorsSpace: space, colors: colors, locations: locations) else {
    fatalError("Failed to create linear gradient")
}
ctx.drawLinearGradient(
    linear,
    start: CGPoint(x: 120, y: 1024),
    end: CGPoint(x: 920, y: 60),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)

let glowColors = [
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.20),
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
] as CFArray
let glowStops: [CGFloat] = [0.0, 1.0]
guard let radial = CGGradient(colorsSpace: space, colors: glowColors, locations: glowStops) else {
    fatalError("Failed to create radial gradient")
}
ctx.drawRadialGradient(
    radial,
    startCenter: CGPoint(x: 300, y: 780),
    startRadius: 0,
    endCenter: CGPoint(x: 300, y: 780),
    endRadius: 420,
    options: []
)

// Minimal runner mark for small-size legibility.
let swoosh = NSBezierPath()
swoosh.lineCapStyle = .round
swoosh.lineJoinStyle = .round
swoosh.lineWidth = 124
swoosh.move(to: NSPoint(x: 250, y: 300))
swoosh.curve(
    to: NSPoint(x: 760, y: 720),
    controlPoint1: NSPoint(x: 400, y: 560),
    controlPoint2: NSPoint(x: 615, y: 760)
)
NSColor.white.withAlphaComponent(0.97).setStroke()
swoosh.stroke()

let head = NSBezierPath(ovalIn: NSRect(x: 650, y: 560, width: 170, height: 170))
NSColor.white.withAlphaComponent(0.97).setFill()
head.fill()

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Failed to encode PNG")
}

let outDir = URL(fileURLWithPath: "assets/app_icon", isDirectory: true)
let outPath = outDir.appendingPathComponent("app_icon_ios_1024.png")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
try pngData.write(to: outPath)
print("Generated: \(outPath.path)")
