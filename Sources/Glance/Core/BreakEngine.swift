import Combine
import Foundation

/// Where the user is in the focus/break cycle.
enum GlancePhase: Equatable {
    /// Accumulating screen time.
    case focusing
    /// A break is owed, but the moment is bad. Holding.
    case smartPaused(PauseReason)
    /// The moment cleared. Letting the user land before reminding.
    case waitingToResume
    /// Overlay is offering the break.
    case breakDue
    /// Break is running.
    case breaking
    /// Break just finished.
    case complete

    var showsOverlay: Bool {
        switch self {
        case .breakDue, .breaking, .complete: return true
        default: return false
        }
    }
}

/// The focus timer and the rules around when it is allowed to interrupt.
@MainActor
final class BreakEngine: ObservableObject {

    @Published private(set) var phase: GlancePhase = .focusing
    @Published private(set) var focusElapsed: TimeInterval = 0
    @Published private(set) var breakRemaining: TimeInterval = 0
    @Published private(set) var activity: BreakActivity = BreakActivity.all[0]

    private let settings: GlanceSettings
    private let context: ContextEngine
    private let log: SessionLog

    private var ticker: Timer?
    private var lastTick = Date()
    private var resumeDeadline = Date.distantFuture
    private var completeUntil = Date.distantFuture
    private var activityIndex = 0

    /// A break offer left untouched this long starts on its own, so the cycle
    /// still works when the user has already walked away from the keyboard.
    private let unattendedStartDelay: TimeInterval = 10
    private var breakDueSince = Date.distantFuture

    /// Idle shorter than this is thinking, not a break.
    private let idleGracePeriod: TimeInterval = 60

    init(settings: GlanceSettings, log: SessionLog = .shared) {
        self.settings = settings
        self.context = ContextEngine(settings: settings)
        self.log = log
    }

    func start() {
        lastTick = Date()
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // Nothing here needs sub-100ms precision, and the slack lets the system
        // coalesce this wakeup with others instead of forcing an exact edge
        // every second for the life of the app.
        timer.tolerance = 0.1
        ticker = timer
    }

    // MARK: Derived state

    var progress: Double {
        guard settings.focusInterval > 0 else { return 0 }
        return min(focusElapsed / settings.focusInterval, 1)
    }

    var timeUntilBreak: TimeInterval {
        max(settings.focusInterval - focusElapsed, 0)
    }

    var breakProgress: Double {
        guard settings.breakDuration > 0 else { return 1 }
        return 1 - min(breakRemaining / settings.breakDuration, 1)
    }

    // MARK: User actions

    /// Begin the break the overlay is offering, or one the user asked for.
    func beginBreak() {
        pickNextActivity()
        breakRemaining = settings.breakDuration
        phase = .breaking
    }

    /// Bring a break forward from the menu bar. Ignored when a break is
    /// already on screen, so a stray click cannot restart one in flight and
    /// swap the prompt out from under the user.
    func requestBreakNow() {
        guard !phase.showsOverlay else { return }
        settings.pausedUntil = nil
        focusElapsed = settings.focusInterval
        beginBreak()
    }

    /// Stay quiet until a chosen time.
    func pause(until date: Date) {
        settings.pausedUntil = date
    }

    func resumeFromManualPause() {
        settings.pausedUntil = nil
    }

    /// "Skip for now" — no guilt, no immediate re-ask.
    func skip() {
        focusElapsed = 0
        phase = .focusing
    }

    /// "5 more minutes".
    func snooze() {
        focusElapsed = max(settings.focusInterval - settings.snoozeDuration, 0)
        phase = .focusing
    }

    private func finishBreak() {
        log.recordCompletedBreak()
        focusElapsed = 0
        completeUntil = Date().addingTimeInterval(2.5)
        phase = .complete
    }

    private func pickNextActivity() {
        let choices = BreakActivity.enabled(from: settings.enabledActivityIDs)
        activity = choices[activityIndex % choices.count]
        activityIndex += 1
    }

    // MARK: Tick

    private func tick() {
        let now = Date()
        // Clamped at both ends. The upper bound stops sleep/wake dumping a
        // huge delta into the timer; the lower bound matters just as much,
        // because a backward clock step (NTP correction, DST, the user setting
        // the clock) yields a negative interval, which would drive focus time
        // negative and, mid-break, *extend* the countdown by the size of the
        // jump.
        let delta = max(0, min(now.timeIntervalSince(lastTick), 5))
        lastTick = now

        let idle = IdleMonitor.idleSeconds()
        let reason = context.currentPauseReason()

        switch phase {
        case .focusing:
            advanceFocus(by: delta, idle: idle, reason: reason)

        case .smartPaused:
            // Deliberately no natural-break check here. Idle time cannot tell
            // "away from the desk" apart from "watching a call without
            // typing", and during a call or presentation the user is looking
            // at the screen the whole time. Resetting would silently cancel a
            // break they genuinely earned; not resetting only risks one extra
            // break, which is the safer way to be wrong.
            focusElapsed += delta
            if let reason {
                phase = .smartPaused(reason)
            } else {
                resumeDeadline = now.addingTimeInterval(settings.postContextDelay)
                phase = .waitingToResume
            }

        case .waitingToResume:
            focusElapsed += delta
            if let reason {
                phase = .smartPaused(reason)
            } else if tookNaturalBreak(idle: idle) {
                focusElapsed = 0
                phase = .focusing
            } else if now >= resumeDeadline {
                offerBreak(at: now)
            }

        case .breakDue:
            // The offer sits on screen for a few seconds before starting on its
            // own. A call or presentation can begin inside that window, so this
            // has to keep checking rather than commit to interrupting.
            if let reason {
                phase = .smartPaused(reason)
            } else if now.timeIntervalSince(breakDueSince) >= unattendedStartDelay {
                beginBreak()
            }

        case .breaking:
            // Same reasoning once the break is running: if a call starts, the
            // user needs their screen back now. Focus time is still owed, so
            // the break is re-offered when the call ends.
            if let reason {
                phase = .smartPaused(reason)
                return
            }
            breakRemaining -= delta
            if breakRemaining <= 0 {
                breakRemaining = 0
                finishBreak()
            }

        case .complete:
            if now >= completeUntil {
                phase = .focusing
            }
        }
    }

    private func advanceFocus(by delta: TimeInterval, idle: TimeInterval, reason: PauseReason?) {
        if tookNaturalBreak(idle: idle) {
            focusElapsed = 0
            return
        }
        // Short idle stretches simply do not count as screen time.
        if !(settings.respectIdle && idle >= idleGracePeriod) {
            focusElapsed += delta
        }

        guard focusElapsed >= settings.focusInterval else { return }

        if let reason {
            phase = .smartPaused(reason)
        } else {
            offerBreak(at: Date())
        }
    }

    private func offerBreak(at now: Date) {
        pickNextActivity()
        breakRemaining = settings.breakDuration
        breakDueSince = now
        phase = .breakDue
    }

    private func tookNaturalBreak(idle: TimeInterval) -> Bool {
        settings.respectIdle && idle >= settings.idleResetThreshold
    }
}
