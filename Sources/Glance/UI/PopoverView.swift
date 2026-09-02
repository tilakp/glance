import SwiftUI

/// The menu bar popover. Deliberately close to empty: a ring, one number,
/// one button.
struct PopoverView: View {
    @ObservedObject var engine: BreakEngine
    @ObservedObject var settings: GlanceSettings
    @ObservedObject var log: SessionLog

    var body: some View {
        VStack(spacing: 0) {
            header

            Group {
                if engine.phase.showsOverlay {
                    // A break is on screen. Offering "Take a break now" here
                    // would restart the one already running.
                    breakRunningBody
                } else if case .smartPaused(let reason) = engine.phase {
                    pausedBody(reason)
                } else if case .waitingToResume = engine.phase {
                    resumingBody
                } else {
                    focusBody
                }
            }
            .padding(.top, 18)

            Divider()
                .padding(.top, 20)

            footer
        }
        .padding(18)
        .frame(width: 268)
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            Text("Glance")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var focusBody: some View {
        VStack(spacing: 0) {
            FocusRing(progress: engine.progress)
                .frame(width: 92, height: 92)

            Text("\(formatted(engine.focusElapsed)) focused")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 16)

            Text("Next eye break in")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 14)

            Text(formatted(engine.timeUntilBreak))
                .font(.glanceNumeral(30))
                .monospacedDigit()
                .padding(.top, 2)

            Button(action: engine.requestBreakNow) {
                Text("Take a break now")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(Palette.indigo)
            .padding(.top, 18)

            Button("Pause for 1 hour") {
                engine.pause(until: Date().addingTimeInterval(3600))
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.top, 10)
        }
    }

    /// Shown while the overlay is up, so the popover cannot fight with it.
    private var breakRunningBody: some View {
        VStack(spacing: 0) {
            Image(systemName: "leaf")
                .font(.system(size: 30, weight: .ultraLight))
                .foregroundStyle(Palette.violet)
                .frame(height: 92)
                .accessibilityHidden(true)

            Text("Break in progress")
                .font(.system(size: 15, weight: .medium))

            Text("Look somewhere far away.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }

    private func pausedBody(_ reason: PauseReason) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "pause.circle")
                .font(.system(size: 34, weight: .ultraLight))
                .foregroundStyle(.secondary)
                .frame(height: 92)

            Text("Paused")
                .font(.system(size: 15, weight: .medium))

            Text(reason.headline)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            Text(reason.explanation)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            if case .manual = reason {
                Button("Resume reminders", action: engine.resumeFromManualPause)
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.indigo)
                    .padding(.top, 14)
            }
        }
    }

    private var resumingBody: some View {
        VStack(spacing: 0) {
            Image(systemName: "hand.wave")
                .font(.system(size: 30, weight: .ultraLight))
                .foregroundStyle(Palette.violet)
                .frame(height: 92)

            Text("Welcome back.")
                .font(.system(size: 15, weight: .medium))

            Text("An eye break is ready when you are.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Button(action: engine.beginBreak) {
                Text("Start now")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(Palette.indigo)
            .padding(.top, 16)
        }
    }

    private var footer: some View {
        HStack {
            Text("Today")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(log.breaksToday == 1 ? "1 break" : "\(log.breaksToday) breaks")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.leading, 10)
        }
        .padding(.top, 12)
    }

    private func formatted(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// The focus ring, in Glance's indigo → violet → lavender.
private struct FocusRing: View {
    var progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.16), lineWidth: 6)

            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(Palette.ring, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)

            Image(systemName: "eye")
                .font(.system(size: 20, weight: .ultraLight))
                .foregroundStyle(Palette.violet)
        }
        .accessibilityElement()
        .accessibilityLabel("Focus progress")
        .accessibilityValue("\(Int(progress * 100)) percent toward your next eye break")
    }
}
