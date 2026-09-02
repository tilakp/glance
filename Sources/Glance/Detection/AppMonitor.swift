import AppKit

/// The app the user is currently working in.
enum AppMonitor {
    static func frontmostBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    static func displayName(for bundleID: String) -> String {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let name = running.localizedName {
            return name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
        }
        return knownNames[bundleID] ?? bundleID
    }

    /// Glance ships with a few video-call apps pre-listed. When one of them is
    /// not installed there is nothing to read a name from, and a raw bundle
    /// identifier in the settings list is not a useful thing to show a person.
    private static let knownNames = [
        "us.zoom.xos": "Zoom",
        "com.microsoft.teams2": "Microsoft Teams",
        "com.apple.iWork.Keynote": "Keynote",
    ]
}
