import SwiftUI

/// The full-screen break experience: offer, break, and a brief thank-you.
struct BreakOverlayView: View {
    @ObservedObject var engine: BreakEngine
    @ObservedObject var settings: GlanceSettings
    @ObservedObject var log: SessionLog

    /// Only the display holding the pointer shows controls and copy; the others
    /// show the backdrop alone, so a multi-display setup does not shout in
    /// triplicate.
    var isPrimary: Bool

    @State private var appeared = false
    @StateObject private var clock = VisibleClock()

    /// Motion is suppressed for the system-wide accessibility setting as well
    /// as Glance's own, and on displays that carry no content: a full-screen
    /// 30fps Canvas per monitor was the single most expensive thing this app
    /// did, and a secondary screen showing no text gains nothing from drift.
    private var palette: RestPalette { settings.breakAppearance.palette }

    private var animated: Bool { !settings.prefersReducedMotion && isPrimary }

    var body: some View {
        ZStack {
            DistanceBackdrop(animated: animated, palette: palette)

            if isPrimary {
                content
                    .padding(48)
                    .scaleEffect(appeared ? 1 : 0.98)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch engine.phase {
        case .breakDue: offer
        case .breaking: inProgress
        case .complete: completion
        default: EmptyView()
        }
    }

    // MARK: Offer

    private var offer: some View {
        VStack(spacing: 0) {
            GazeMark(animated: animated, palette: palette)
                .frame(width: 92, height: 92)
                .accessibilityHidden(true)

            Text("Time to look away.")
                .font(.system(size: 34, weight: .regular, design: .rounded))
                .foregroundStyle(palette.text)
                .padding(.top, 34)

            Text("Give your eyes some distance.")
                .font(.system(size: 17))
                .foregroundStyle(palette.text.opacity(0.78))
                .padding(.top, 10)

            Text(durationPhrase)
                .font(.glanceNumeral(20))
                .foregroundStyle(palette.accent)
                .padding(.top, 28)

            PrimaryButton(title: "Start break", palette: palette, action: engine.beginBreak)
                // Return activates it. macOS Full Keyboard Access is off by
                // default, so without an explicit shortcut a keyboard-only
                // user could reach Skip (via Escape) but never Start.
                .keyboardShortcut(.defaultAction)
                .padding(.top, 36)

            HStack(spacing: 28) {
                QuietButton(title: "5 more minutes", palette: palette, action: engine.snooze)
                QuietButton(title: "Skip for now", palette: palette, action: engine.skip)
            }
            .padding(.top, 18)

            Text("Return to start · Esc to skip")
                .font(.system(size: 11))
                .foregroundStyle(palette.text.opacity(0.75))
                .accessibilityHidden(true)
                .padding(.top, 22)
        }
    }

    private var secondsRemaining: Int {
        Int(engine.breakRemaining.rounded(.up))
    }

    private var durationPhrase: String {
        let seconds = Int(settings.breakDuration.rounded())
        if seconds % 60 == 0 && seconds >= 60 {
            let minutes = seconds / 60
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
        return "\(seconds) seconds"
    }

    // MARK: Break running

    /// `breakRemaining` is not published at 1Hz any more (BreakEngine.swift),
    /// so the countdown drives its own clock here, started and stopped as
    /// this body actually appears and disappears.
    private var inProgress: some View {
        VStack(spacing: 0) {
            let _ = clock.now

            Image(systemName: engine.activity.symbol)
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(palette.accent)
                .frame(height: 52)
                .accessibilityHidden(true)

            Text(engine.activity.title)
                .font(.system(size: 30, weight: .regular, design: .rounded))
                .foregroundStyle(palette.text)
                .padding(.top, 26)

            Text(engine.activity.detail)
                .font(.system(size: 16))
                .foregroundStyle(palette.text.opacity(0.78))
                .padding(.top, 10)

            // Driven by whole seconds, and only animated when motion is
            // wanted: a glyph-morphing transition plus the dot fades below
            // keep a full-screen hosting view re-compositing at display rate
            // for a large fraction of every second.
            Text("\(secondsRemaining)")
                .font(.glanceNumeral(104))
                .foregroundStyle(palette.text.opacity(0.88))
                .monospacedDigit()
                .contentTransition(animated ? .numericText(countsDown: true) : .identity)
                .animation(animated ? .easeOut(duration: 0.2) : nil, value: secondsRemaining)
                .accessibilityLabel("\(Int(engine.breakRemaining.rounded(.up))) seconds remaining")
                .padding(.top, 26)

            DotProgress(progress: engine.breakProgress, count: 10, animated: animated, palette: palette)
                .padding(.top, 22)
                .accessibilityHidden(true)

            QuietButton(title: "Skip", palette: palette, action: engine.skip)
                .keyboardShortcut(.cancelAction)
                .padding(.top, 40)
        }
        .onAppear { clock.start() }
        .onDisappear { clock.stop() }
    }

    // MARK: Completion

    private var completion: some View {
        VStack(spacing: 0) {
            Image(systemName: "checkmark")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(palette.success)
                .frame(height: 52)
                .accessibilityHidden(true)

            Text("Nice break.")
                .font(.system(size: 30, weight: .regular, design: .rounded))
                .foregroundStyle(palette.text)
                .padding(.top, 26)

            Text("See you again soon.")
                .font(.system(size: 16))
                .foregroundStyle(palette.text.opacity(0.78))
                .padding(.top, 10)

            DotProgress(progress: 1, count: min(max(log.breaksToday, 1), 12), animated: animated, palette: palette)
                .padding(.top, 30)
                .accessibilityHidden(true)

            Text(log.breaksToday == 1 ? "1 break today" : "\(log.breaksToday) breaks today")
                .font(.system(size: 13))
                .foregroundStyle(palette.text.opacity(0.78))
                .padding(.top, 14)
        }
    }
}

// MARK: - Pieces

/// A slow outward "look away" motion: the pupil drifts off centre and settles.
private struct GazeMark: View {
    var animated: Bool
    var palette: RestPalette
    @State private var shift: CGFloat = 0
    @State private var breathe: CGFloat = 1

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.accent.opacity(0.28), lineWidth: 1.5)
                .scaleEffect(breathe)

            Circle()
                .stroke(palette.accent.opacity(0.50), lineWidth: 2)
                .frame(width: 52, height: 52)

            Circle()
                .fill(palette.accent)
                .frame(width: 15, height: 15)
                .offset(x: shift)
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                shift = 13
                breathe = 1.10
            }
        }
    }
}

/// Soft dot progression. Reads as a rhythm rather than a stopwatch.
private struct DotProgress: View {
    var progress: Double
    var count: Int
    var animated: Bool
    var palette: RestPalette

    var body: some View {
        HStack(spacing: 11) {
            ForEach(0..<count, id: \.self) { index in
                let filled = Double(index) < progress * Double(count)
                Circle()
                    .fill(filled ? palette.accent : palette.text.opacity(0.14))
                    .frame(width: 7, height: 7)
                    .animation(animated ? .easeOut(duration: 0.35) : nil, value: filled)
            }
        }
    }
}

private struct PrimaryButton: View {
    var title: String
    var palette: RestPalette
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.text)
                .padding(.horizontal, 34)
                .padding(.vertical, 13)
                .background(
                    Capsule().fill(palette.accent.opacity(hovering ? 0.24 : 0.15))
                )
                .overlay(
                    Capsule().stroke(palette.accent.opacity(hovering ? 0.50 : 0.30), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

private struct QuietButton: View {
    var title: String
    var palette: RestPalette
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(palette.text.opacity(hovering ? 0.95 : 0.78))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}
