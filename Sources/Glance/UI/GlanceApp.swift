import AppKit
import SwiftUI

/// Owns the long-lived objects. The menu bar popover is only built when it is
/// opened, so the timer cannot be started from inside it.
@MainActor
final class AppCore {
    static let shared = AppCore()

    let settings = GlanceSettings.shared
    let log = SessionLog.shared
    let engine: BreakEngine
    private let overlay: OverlayController

    private init() {
        engine = BreakEngine(settings: settings)
        overlay = OverlayController(engine: engine, settings: settings, log: log)
    }

    func start() {
        overlay.observe()
        engine.start()
    }
}

@main
struct GlanceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    @StateObject private var engine = AppCore.shared.engine
    @StateObject private var settings = GlanceSettings.shared
    @StateObject private var log = SessionLog.shared

    var body: some Scene {
        MenuBarExtra {
            PopoverView(engine: engine, settings: settings, log: log)
        } label: {
            Image(nsImage: MenuBarIcon.image(progress: engine.progress, phase: engine.phase))
                .accessibilityLabel("Glance")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only: no Dock icon, no app switcher entry.
        NSApp.setActivationPolicy(.accessory)
        AppCore.shared.start()
    }
}
