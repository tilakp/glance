import AppKit

/// Draws the menu bar ring. It fills as screen time accumulates, and hollows
/// out to a dashed outline while Smart Pause is holding a reminder back.
enum MenuBarIcon {
    private struct Key: Equatable {
        let progressStep: Int
        let phase: GlancePhase
    }

    private static var cache: (key: Key, image: NSImage)?

    /// The focus timer ticks every second, but a one-second change in progress
    /// is not visible on an 18pt ring. Redrawing only when the rounded degree
    /// (or phase) actually changes avoids rebuilding the image on every tick.
    static func image(progress: Double, phase: GlancePhase) -> NSImage {
        let key = Key(progressStep: Int((progress * 360).rounded()), phase: phase)
        if let cache, cache.key == key { return cache.image }
        let rendered = render(progress: progress, phase: phase)
        cache = (key, rendered)
        return rendered
    }

    private static func render(progress: Double, phase: GlancePhase) -> NSImage {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let center = NSPoint(x: side / 2, y: side / 2)
            let radius: CGFloat = 6.9
            let width: CGFloat = 1.7

            switch phase {
            case .smartPaused, .waitingToResume:
                let ring = NSBezierPath()
                ring.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
                ring.lineWidth = width
                ring.setLineDash([2.2, 2.6], count: 2, phase: 0)
                NSColor.black.withAlphaComponent(0.55).setStroke()
                ring.stroke()

            case .breakDue, .breaking, .complete:
                let dot = NSBezierPath(ovalIn: NSRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2))
                NSColor.black.setFill()
                dot.fill()

            case .focusing:
                let track = NSBezierPath()
                track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
                track.lineWidth = width
                NSColor.black.withAlphaComponent(0.45).setStroke()
                track.stroke()

                if progress > 0.001 {
                    let arc = NSBezierPath()
                    arc.appendArc(
                        withCenter: center, radius: radius,
                        startAngle: 90,
                        endAngle: 90 - 360 * progress,
                        clockwise: true
                    )
                    arc.lineWidth = width
                    arc.lineCapStyle = .round
                    NSColor.black.setStroke()
                    arc.stroke()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
