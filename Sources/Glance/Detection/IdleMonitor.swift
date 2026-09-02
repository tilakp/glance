import CoreGraphics
import Foundation

/// Seconds since the last keyboard, mouse or trackpad event.
enum IdleMonitor {
    static func idleSeconds() -> TimeInterval {
        // `~0` is the documented "any event type" wildcard.
        guard let anyEvent = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyEvent)
    }
}
