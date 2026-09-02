import AppKit
import Combine
import SwiftUI

/// Borderless windows do not accept key input by default, but the overlay
/// needs Escape to work.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// Puts the break overlay on every display, and takes it away again.
@MainActor
final class OverlayController {
    private let engine: BreakEngine
    private let settings: GlanceSettings
    private let log: SessionLog

    private var windows: [OverlayWindow] = []
    private var escapeMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var cancellable: AnyCancellable?

    init(engine: BreakEngine, settings: GlanceSettings, log: SessionLog) {
        self.engine = engine
        self.settings = settings
        self.log = log
    }

    func observe() {
        cancellable = engine.$phase
            .map(\.showsOverlay)
            .removeDuplicates()
            .sink { [weak self] shouldShow in
                Task { @MainActor in
                    shouldShow ? self?.show() : self?.hide()
                }
            }
    }

    private func show() {
        guard windows.isEmpty else { return }
        previousApp = NSWorkspace.shared.frontmostApplication

        // Read the screen list once: the controls are placed by index, so a
        // second call returning a different list would mismatch them.
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        // Put the controls on the display holding the pointer. Two traps here:
        // `CGRect.contains` excludes the top and right edges, so a pointer
        // parked in the menu bar matches nothing; and `NSScreen.main` is
        // optional and can be nil for a background accessory app. Falling back
        // to an index guarantees exactly one display always has the controls.
        let pointer = NSEvent.mouseLocation
        let primaryIndex = screens.firstIndex {
            $0.frame.insetBy(dx: -1, dy: -1).contains(pointer)
        } ?? 0

        for (index, screen) in screens.enumerated() {
            let root = BreakOverlayView(
                engine: engine,
                settings: settings,
                log: log,
                isPrimary: index == primaryIndex
            )

            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: root)
            window.alphaValue = 0
            window.orderFrontRegardless()
            windows.append(window)
        }

        // Make the window that actually carries the controls the key one.
        // Keying `windows.first` instead would key whichever display macOS
        // lists first, so on a secondary-monitor setup the first click on
        // "Start break" would be swallowed as a window-activation click.
        if primaryIndex < windows.count {
            windows[primaryIndex].makeKey()
        }
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            windows.forEach { $0.animator().alphaValue = 1 }
        }

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // 53 is Escape.
            guard event.keyCode == 53 else { return event }
            Task { @MainActor in self?.engine.skip() }
            return nil
        }
    }

    private func hide() {
        guard !windows.isEmpty else { return }
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }

        let closing = windows
        windows = []
        // Taken synchronously: a fast skip-then-retrigger can run show() again
        // before this animation's completion handler fires, and reading the
        // field in there would restore the wrong app and then clear it.
        let restoring = previousApp
        previousApp = nil

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.30
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            closing.forEach { $0.animator().alphaValue = 0 }
        } completionHandler: {
            closing.forEach { $0.close() }
        }

        // Hand the user back to whatever they were doing.
        restoring?.activate()
    }
}
