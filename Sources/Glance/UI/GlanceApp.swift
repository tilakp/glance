import AppKit
import Combine
import SwiftUI

/// Owns the long-lived objects. The menu bar popover is only built when it is
/// opened, so the timer cannot be started from inside it.
@MainActor
final class AppCore {
    static let shared = AppCore()

    let settings = GlanceSettings.shared
    let log = SessionLog.shared
    let engine: BreakEngine
    let popoverClock = VisibleClock()
    private let overlay: OverlayController
    private var occlusionObserver: NSObjectProtocol?
    private var overlayCancellable: AnyCancellable?

    private init() {
        engine = BreakEngine(settings: settings)
        overlay = OverlayController(engine: engine, settings: settings, log: log)
    }

    func start() {
        overlay.observe()
        engine.start()
        observePopoverVisibility()
    }

    /// `MenuBarExtra(.window)`'s popover window is created once and reused:
    /// closing it does not destroy it, only flips `occlusionState`, and
    /// neither `TimelineView` nor `onAppear`/`onDisappear` inside its content
    /// notice that (measured on macOS 26 - see `VisibleClock`). Reading
    /// occlusion directly is the one signal that actually tracks whether the
    /// popover is on screen, so the popover's live countdown is driven from
    /// here instead of from the view itself.
    ///
    /// 268pt is `PopoverView`'s declared width and is not shared by any other
    /// window this app creates (the break overlay fills the display).
    private func observePopoverVisibility() {
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let window = note.object as? NSWindow, window.frame.width == 268 else { return }
            let visible = window.occlusionState.contains(.visible)
            Task { @MainActor in
                visible ? self?.popoverClock.start() : self?.popoverClock.stop()
            }
        }

        // Measured: taking a break from an open popover (clicking "Take a
        // break now") does not reliably deliver an occlusion notification for
        // the popover before the full-screen overlay takes over, which would
        // otherwise leave the popover's clock running with nothing on screen
        // to show it. The overlay's own visibility is unambiguous, so it
        // doubles as a stop signal here.
        overlayCancellable = engine.$phase
            .map(\.showsOverlay)
            .filter { $0 }
            .sink { [weak self] _ in self?.popoverClock.stop() }
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
            PopoverView(engine: engine, settings: settings, log: log, clock: AppCore.shared.popoverClock)
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
