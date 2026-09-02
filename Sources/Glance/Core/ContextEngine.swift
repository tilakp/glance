import Foundation

/// Why Glance is holding a reminder back.
enum PauseReason: Equatable {
    case manual(until: Date)
    case camera
    case presenting
    case app(name: String)

    var headline: String {
        switch self {
        case .manual(let until):
            return "Paused until \(until.formatted(date: .omitted, time: .shortened))"
        case .camera: return "Camera is active"
        case .presenting: return "You're presenting"
        case .app(let name): return "\(name) is active"
        }
    }

    var explanation: String {
        switch self {
        case .manual: return "You asked Glance to stay quiet for a while."
        case .camera: return "Reminders will resume when your call ends."
        case .presenting: return "Reminders will resume when you finish."
        case .app: return "Reminders will resume when you switch away."
        }
    }
}

/// Answers one question: is right now a good moment to interrupt?
///
/// Results are cached briefly because the window-list scan behind
/// presentation detection is the most expensive check.
final class ContextEngine {
    private let settings: GlanceSettings
    private var cached: PauseReason??
    private var cachedAt = Date.distantPast
    private let cacheLifetime: TimeInterval = 2

    init(settings: GlanceSettings) {
        self.settings = settings
    }

    func currentPauseReason() -> PauseReason? {
        if let cached, Date().timeIntervalSince(cachedAt) < cacheLifetime {
            return cached
        }
        let reason = evaluate()
        cached = reason
        cachedAt = Date()
        return reason
    }

    private func evaluate() -> PauseReason? {
        if let until = settings.pausedUntil {
            return .manual(until: until)
        }
        if settings.pauseOnCamera, CameraMonitor.isCameraInUse() {
            return .camera
        }
        if settings.pauseForApps,
           let front = AppMonitor.frontmostBundleID(),
           settings.pausedAppIDs.contains(front) {
            return .app(name: AppMonitor.displayName(for: front))
        }
        if settings.pauseOnPresenting, PresentationMonitor.isPresenting() {
            return .presenting
        }
        return nil
    }
}
