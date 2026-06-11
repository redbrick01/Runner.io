import AppKit
import Foundation

struct IconOutput {
    let path: String
    let size: Int
}

let canvasSize = 1024
let designSize: CGFloat = 188

func color(hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255.0,
        green: CGFloat((hex >> 8) & 0xff) / 255.0,
        blue: CGFloat(hex & 0xff) / 255.0,
        alpha: alpha
    )
}

func renderIcon(size: Int) -> NSBitmapImageRep {
    let side = CGFloat(size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Failed to get graphics context")
    }

    bitmap.size = NSSize(width: side, height: side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics

    let ctx = graphics.cgContext
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        color(hex: 0x1438de).cgColor,
        color(hex: 0x00d47e).cgColor,
    ] as CFArray
    let gradientLocations: [CGFloat] = [0, 1]
    guard let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: gradientColors,
        locations: gradientLocations
    ) else {
        fatalError("Failed to create gradient")
    }

    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: side),
        end: CGPoint(x: side, y: 0),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    // Preserve the proportions of the selected "Route Territory" web mockup.
    let scale = side / designSize
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: x * scale, y: (designSize - y) * scale)
    }
    func rectBottom(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
    }

    let land = NSBezierPath()
    land.move(to: point(58.16, 57.44))
    land.line(to: point(110.8, 46.64))
    land.line(to: point(136.56, 79.04))
    land.line(to: point(118.64, 132.56))
    land.line(to: point(71.6, 135.2))
    land.line(to: point(46.96, 100.64))
    land.close()
    color(hex: 0xffffff, alpha: 0.94).setFill()
    land.fill()

    func drawRoute(x: CGFloat, y: CGFloat, width: CGFloat, fill: NSColor) {
        ctx.saveGState()
        ctx.translateBy(x: (x + width / 2) * scale, y: (designSize - y - 7) * scale)
        ctx.rotate(by: -18 * .pi / 180)
        let route = NSBezierPath(
            roundedRect: rectBottom(-width / 2, -7, width, 14),
            xRadius: 7 * scale,
            yRadius: 7 * scale
        )
        fill.setFill()
        route.fill()
        ctx.restoreGState()
    }

    drawRoute(x: 50, y: 74, width: 94, fill: color(hex: 0x1438de))
    drawRoute(x: 50, y: 106, width: 94, fill: color(hex: 0x00d47e))

    color(hex: 0xffffff).setFill()
    NSBezierPath(ovalIn: rectBottom(127, 48, 24, 24)).fill()
    color(hex: 0xffb800).setFill()
    NSBezierPath(ovalIn: rectBottom(132, 53, 14, 14)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func pngData(size: Int) -> Data {
    guard let data = renderIcon(size: size).representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG")
    }
    return data
}

func writePNG(path: String, size: Int) throws {
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try pngData(size: size).write(to: url)
}

func writeICO(path: String, sizes: [Int]) throws {
    let images = sizes.map { ($0, pngData(size: $0)) }
    var data = Data()

    func appendUInt16(_ value: UInt16) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
    }

    func appendUInt32(_ value: UInt32) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
    }

    appendUInt16(0)
    appendUInt16(1)
    appendUInt16(UInt16(images.count))

    var offset = 6 + images.count * 16
    for (size, imageData) in images {
        data.append(UInt8(size >= 256 ? 0 : size))
        data.append(UInt8(size >= 256 ? 0 : size))
        data.append(0)
        data.append(0)
        appendUInt16(1)
        appendUInt16(32)
        appendUInt32(UInt32(imageData.count))
        appendUInt32(UInt32(offset))
        offset += imageData.count
    }

    for (_, imageData) in images {
        data.append(imageData)
    }

    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
}

let outputs: [IconOutput] = [
    IconOutput(path: "assets/app_icon/app_icon_ios_1024.png", size: 1024),

    IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png", size: 20),
    IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png", size: 40),
    IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png", size: 60),
    IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png", size: 29),
    IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png", size: 58),
    IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png", size: 87),
    IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png", size: 40),
    IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png", size: 80),
    IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png", size: 120),
    IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png", size: 120),
    IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png", size: 180),
    IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png", size: 76),
    IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png", size: 152),
    IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png", size: 167),
    IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", size: 1024),

    IconOutput(path: "android/app/src/main/res/mipmap-mdpi/ic_launcher.png", size: 48),
    IconOutput(path: "android/app/src/main/res/mipmap-hdpi/ic_launcher.png", size: 72),
    IconOutput(path: "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png", size: 96),
    IconOutput(path: "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png", size: 144),
    IconOutput(path: "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", size: 192),

    IconOutput(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png", size: 16),
    IconOutput(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png", size: 32),
    IconOutput(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png", size: 64),
    IconOutput(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png", size: 128),
    IconOutput(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png", size: 256),
    IconOutput(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png", size: 512),
    IconOutput(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png", size: 1024),

    IconOutput(path: "web/favicon.png", size: 32),
    IconOutput(path: "web/icons/Icon-192.png", size: 192),
    IconOutput(path: "web/icons/Icon-maskable-192.png", size: 192),
    IconOutput(path: "web/icons/Icon-512.png", size: 512),
    IconOutput(path: "web/icons/Icon-maskable-512.png", size: 512),
]

for output in outputs {
    try writePNG(path: output.path, size: output.size)
    print("Generated \(output.path) (\(output.size)x\(output.size))")
}

try writeICO(path: "windows/runner/resources/app_icon.ico", sizes: [16, 32, 48, 64, 128, 256])
print("Generated windows/runner/resources/app_icon.ico")
