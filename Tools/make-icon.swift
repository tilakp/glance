#!/usr/bin/env swift
// Generates Glance's app icon: an abstract gaze — an outer circle of attention,
// an inner ring, and a pupil sitting slightly off centre to suggest a glance
// outward. Indigo to violet, per the Glance identity.

import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./icon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func draw(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return true }

        // macOS icons leave breathing room around the squircle.
        let inset = size * 0.085
        let box = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
        let squircle = CGPath(roundedRect: box,
                              cornerWidth: box.width * 0.225,
                              cornerHeight: box.height * 0.225,
                              transform: nil)

        ctx.saveGState()
        ctx.addPath(squircle)
        ctx.clip()

        // Body gradient: deep indigo up into violet.
        let space = CGColorSpaceCreateDeviceRGB()
        let body = CGGradient(colorsSpace: space, colors: [
            NSColor(srgbRed: 0.208, green: 0.180, blue: 0.478, alpha: 1).cgColor,
            NSColor(srgbRed: 0.357, green: 0.357, blue: 0.839, alpha: 1).cgColor,
            NSColor(srgbRed: 0.545, green: 0.361, blue: 0.965, alpha: 1).cgColor,
        ] as CFArray, locations: [0, 0.55, 1])!
        ctx.drawLinearGradient(body,
                               start: CGPoint(x: box.minX, y: box.maxY),
                               end: CGPoint(x: box.maxX, y: box.minY),
                               options: [])

        // A horizon glow low in the icon, echoing the break overlay.
        let glow = CGGradient(colorsSpace: space, colors: [
            NSColor(srgbRed: 0.976, green: 0.855, blue: 0.780, alpha: 0.42).cgColor,
            NSColor(srgbRed: 0.976, green: 0.855, blue: 0.780, alpha: 0).cgColor,
        ] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glow,
                               startCenter: CGPoint(x: box.midX, y: box.minY + box.height * 0.12),
                               startRadius: 0,
                               endCenter: CGPoint(x: box.midX, y: box.minY + box.height * 0.12),
                               endRadius: box.width * 0.62,
                               options: [])
        ctx.restoreGState()

        let center = CGPoint(x: box.midX, y: box.midY + box.height * 0.02)
        let lavender = NSColor(srgbRed: 0.878, green: 0.855, blue: 1.0, alpha: 1)

        // Outer gaze sweep. Left open on the right so the mark reads as a
        // glance in a direction, not a target.
        ctx.setStrokeColor(lavender.withAlphaComponent(0.34).cgColor)
        ctx.setLineWidth(max(size * 0.020, 1))
        ctx.setLineCap(.round)
        ctx.addArc(center: center, radius: box.width * 0.355,
                   startAngle: .pi * 0.30, endAngle: .pi * 1.70, clockwise: false)
        ctx.strokePath()

        // Inner ring.
        ctx.setStrokeColor(lavender.withAlphaComponent(0.92).cgColor)
        ctx.setLineWidth(max(size * 0.034, 1))
        ctx.strokeEllipse(in: CGRect(x: center.x - box.width * 0.195,
                                     y: center.y - box.width * 0.195,
                                     width: box.width * 0.39, height: box.width * 0.39))

        // Pupil, carried out toward the opening: the glance itself.
        let pupil = box.width * 0.079
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x + box.width * 0.088 - pupil,
                                   y: center.y - pupil,
                                   width: pupil * 2, height: pupil * 2))

        // A soft trail behind the pupil, suggesting it just moved.
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.20).cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - box.width * 0.055 - pupil * 0.62,
                                   y: center.y - pupil * 0.62,
                                   width: pupil * 1.24, height: pupil * 1.24))

        return true
    }
    return image
}

func writePNG(_ image: NSImage, pixels: Int, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
                        (256, 1), (256, 2), (512, 1), (512, 2)] {
    let pixels = points * scale
    let suffix = scale == 1 ? "" : "@2x"
    writePNG(draw(size: CGFloat(pixels)), pixels: pixels,
             to: "\(outDir)/icon_\(points)x\(points)\(suffix).png")
}
print("wrote iconset to \(outDir)")
