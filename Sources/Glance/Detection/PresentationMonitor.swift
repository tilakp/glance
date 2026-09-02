import AppKit
import CoreGraphics

/// Detects the situations where an interruption would be most costly:
/// mirroring a display to a projector or TV, and running a slideshow or
/// screen share overlay.
///
/// macOS exposes no public "my screen is being captured" flag, so the second
/// check is a heuristic: a window that sits above the normal window layer and
/// covers a whole display is, in practice, a slideshow or a sharing overlay.
/// Requiring a *regular* owning app keeps menu bar agents and wallpaper
/// utilities from matching.
enum PresentationMonitor {

    static func isPresenting() -> Bool {
        isMirroring() || hasFullDisplayOverlayWindow()
    }

    /// True when any active display mirrors another, which is how AirPlay and
    /// most projector setups appear.
    private static func isMirroring() -> Bool {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(16, &ids, &count) == .success else { return false }
        return ids.prefix(Int(count)).contains { CGDisplayMirrorsDisplay($0) != kCGNullDirectDisplay }
    }

    private static func hasFullDisplayOverlayWindow() -> Bool {
        let displays = NSScreen.screens.map(\.frame.size)
        guard !displays.isEmpty else { return false }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        else { return false }

        let ownPID = Int(ProcessInfo.processInfo.processIdentifier)

        // Build the pid -> policy map once. Constructing an NSRunningApplication
        // per candidate window costs a synchronous launchservicesd round trip
        // each time, and several windows usually share one owning process.
        var policies: [Int: NSApplication.ActivationPolicy] = [:]
        for app in NSWorkspace.shared.runningApplications {
            policies[Int(app.processIdentifier)] = app.activationPolicy
        }

        for window in windows {
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            guard layer > 0 else { continue }

            let pid = window[kCGWindowOwnerPID as String] as? Int ?? 0
            guard pid != ownPID, policies[pid] == .regular else { continue }

            guard let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let width = bounds["Width"], let height = bounds["Height"]
            else { continue }

            if displays.contains(where: { covers(width: width, height: height, of: $0) }) {
                return true
            }
        }
        return false
    }

    /// Slideshow and sharing overlays match a display almost exactly; a little
    /// slack absorbs scaling and menu bar insets.
    private static func covers(width: CGFloat, height: CGFloat, of display: CGSize) -> Bool {
        width >= display.width * 0.95 && height >= display.height * 0.95
    }
}
