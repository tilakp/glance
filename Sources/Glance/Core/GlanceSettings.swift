import AppKit
import Foundation
import ServiceManagement

/// User preferences, backed by UserDefaults.
///
/// Values are computed straight off UserDefaults so there is a single source of
/// truth; `objectWillChange` is sent manually on write to keep SwiftUI in sync.
final class GlanceSettings: ObservableObject {
    static let shared = GlanceSettings()

    private let store = UserDefaults.standard

    private func write(_ value: Any?, _ key: String) {
        objectWillChange.send()
        store.set(value, forKey: key)
    }

    private func number(_ key: String, _ fallback: Double) -> Double {
        store.object(forKey: key) as? Double ?? fallback
    }

    private func flag(_ key: String, _ fallback: Bool) -> Bool {
        store.object(forKey: key) as? Bool ?? fallback
    }

    // MARK: Break rhythm

    /// Seconds of accumulated focus before an eye break is due.
    var focusInterval: TimeInterval {
        get { number("focusInterval", 20 * 60) }
        set { write(newValue, "focusInterval") }
    }

    /// Seconds a break lasts.
    var breakDuration: TimeInterval {
        get { number("breakDuration", 20) }
        set { write(newValue, "breakDuration") }
    }

    /// Seconds added when the user asks for more time.
    var snoozeDuration: TimeInterval {
        get { number("snoozeDuration", 5 * 60) }
        set { write(newValue, "snoozeDuration") }
    }

    // MARK: Smart Pause

    var pauseOnCamera: Bool {
        get { flag("pauseOnCamera", true) }
        set { write(newValue, "pauseOnCamera") }
    }

    var pauseOnPresenting: Bool {
        get { flag("pauseOnPresenting", true) }
        set { write(newValue, "pauseOnPresenting") }
    }

    var pauseForApps: Bool {
        get { flag("pauseForApps", true) }
        set { write(newValue, "pauseForApps") }
    }

    /// Bundle identifiers that suppress reminders while frontmost.
    var pausedAppIDs: [String] {
        get { store.stringArray(forKey: "pausedAppIDs") ?? GlanceSettings.defaultPausedApps }
        set { write(newValue, "pausedAppIDs") }
    }

    /// Grace period after a call or presentation ends, before reminding.
    var postContextDelay: TimeInterval {
        get { number("postContextDelay", 30) }
        set { write(newValue, "postContextDelay") }
    }

    // MARK: Natural breaks

    var respectIdle: Bool {
        get { flag("respectIdle", true) }
        set { write(newValue, "respectIdle") }
    }

    /// Idle seconds that count as a full eye break and reset the focus timer.
    var idleResetThreshold: TimeInterval {
        get { number("idleResetThreshold", 180) }
        set { write(newValue, "idleResetThreshold") }
    }

    // MARK: Presentation

    var enabledActivityIDs: [String] {
        get { store.stringArray(forKey: "enabledActivityIDs") ?? BreakActivity.all.map(\.id) }
        set { write(newValue, "enabledActivityIDs") }
    }

    var reduceMotion: Bool {
        get { flag("reduceMotion", false) }
        set { write(newValue, "reduceMotion") }
    }

    /// Honour the system-wide accessibility setting as well as Glance's own
    /// switch. Someone who has asked all of macOS for less motion should not
    /// have to find a second toggle in here.
    var prefersReducedMotion: Bool {
        reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Set while the user has asked for quiet until a given time.
    var pausedUntil: Date? {
        get {
            guard let until = store.object(forKey: "pausedUntil") as? Date,
                  until > Date() else { return nil }
            return until
        }
        set { write(newValue, "pausedUntil") }
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("Glance: could not change launch-at-login: \(error.localizedDescription)")
            }
        }
    }

    /// Video-call and presentation apps most people want covered on day one.
    private static let defaultPausedApps = [
        "us.zoom.xos",
        "com.microsoft.teams2",
        "com.apple.iWork.Keynote",
    ]
}
