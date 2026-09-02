import SwiftUI

/// Glance's focus identity: indigo → violet → lavender, never alarm red.
/// Used for the app icon, the menu bar ring and the popover.
enum Palette {
    static let indigo = Color(red: 0.357, green: 0.357, blue: 0.839)
    static let violet = Color(red: 0.545, green: 0.361, blue: 0.965)
    static let lavender = Color(red: 0.769, green: 0.710, blue: 0.992)

    static let ring = LinearGradient(
        colors: [indigo, violet, lavender],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

/// The break palette, chosen for eyes rather than for branding.
///
/// The overlay fills the whole screen for the length of a break, so it is the
/// one surface where comfort outranks the indigo identity:
///
/// - **Green, not blue.** Short wavelengths focus slightly in front of the
///   retina, so a large blue-violet field keeps the eye hunting for focus.
///   Green sits at the peak of luminous sensitivity, so it reads clearly at
///   much lower intensity.
/// - **Low luminance.** Roughly half the perceived brightness of the indigo
///   field it replaces, so the overlay is a step down from work, not a flash.
/// - **Low contrast.** Text is a soft off-white rather than pure white, and
///   the horizon is a dim wash rather than a glow, so nothing in the frame
///   pulls the eye back to the screen.
enum RestPalette {
    static let night = Color(red: 0.047, green: 0.078, blue: 0.063)
    static let deepNight = Color(red: 0.024, green: 0.043, blue: 0.035)
    static let deep = Color(red: 0.071, green: 0.145, blue: 0.114)
    static let moss = Color(red: 0.113, green: 0.243, blue: 0.188)
    static let sage = Color(red: 0.251, green: 0.439, blue: 0.337)
    /// Accents: dots, symbols, the gaze mark.
    static let mist = Color(red: 0.549, green: 0.749, blue: 0.627)
    /// A dim yellow-green horizon. Never a bright warm glow.
    static let glow = Color(red: 0.678, green: 0.827, blue: 0.694)
    /// Body copy. Off-white with a green cast, not #FFFFFF.
    static let text = Color(red: 0.863, green: 0.910, blue: 0.863)
    /// The completion mark.
    static let mint = Color(red: 0.541, green: 0.792, blue: 0.678)
}

extension Font {
    /// Rounded numerals read as calm rather than clinical.
    static func glanceNumeral(_ size: CGFloat) -> Font {
        .system(size: size, weight: .light, design: .rounded)
    }
}

/// The screen turned into a view of somewhere farther away.
///
/// An abstract horizon rather than a photograph: it reinforces "look into the
/// distance" without competing for attention or shipping megabytes of assets.
struct DistanceBackdrop: View {
    var animated: Bool

    var body: some View {
        // `minimumInterval` is a floor on spacing, not a cap on rate. Measured
        // on an M2 over interleaved A/B rounds: 1/15 and 1/30 are
        // indistinguishable, and a real `.periodic` timer is no better either
        // (28.3% vs 29.2% of a core). The lever that works is `animated`:
        // collapsing to `.infinity` here, together with the gated animations
        // in BreakOverlayView, takes a break from ~29% of a core down to
        // ~1.5%. That is what makes reduced motion and secondary displays
        // cheap.
        TimelineView(.animation(minimumInterval: animated ? 1.0 / 15 : .infinity)) { timeline in
            let t = animated
                ? timeline.date.timeIntervalSinceReferenceDate
                : 0
            Canvas { context, size in
                draw(in: &context, size: size, t: t)
            }
            .ignoresSafeArea()
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let full = CGRect(origin: .zero, size: size)

        // Sky: night at the top easing down into a lit horizon.
        // Every colour here must be fully opaque - the overlay covers the
        // user's screen, and anything translucent leaks their work through it.
        context.fill(Path(full), with: .linearGradient(
            Gradient(colors: [RestPalette.night, RestPalette.deep, RestPalette.moss]),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: size.height * 0.82)
        ))

        // The glow along the horizon line, breathing very slowly. Kept low in
        // the frame so the copy above it stays on darker sky.
        let breathe = 1 + 0.06 * sin(t / 7)
        let horizonY = size.height * 0.80
        let glowWidth = size.width * 1.5 * breathe
        let glowHeight = size.height * 0.46 * breathe
        let glow = CGRect(
            x: size.width / 2 - glowWidth / 2,
            y: horizonY - glowHeight / 2,
            width: glowWidth, height: glowHeight
        )
        context.fill(Path(ellipseIn: glow), with: .radialGradient(
            Gradient(colors: [
                RestPalette.glow.opacity(0.26),
                RestPalette.sage.opacity(0.16),
                .clear,
            ]),
            center: CGPoint(x: glow.midX, y: glow.midY),
            startRadius: 0,
            endRadius: glowWidth / 2
        ))

        // Distant drifting cloud banks. Slow enough to feel like weather.
        for (index, spec) in Self.drifts.enumerated() {
            let phase = t / spec.period + Double(index)
            let x = size.width * (0.5 + 0.34 * sin(phase))
            let y = size.height * spec.y + size.height * 0.012 * cos(phase * 1.3)
            let radius = size.width * spec.radius
            let rect = CGRect(x: x - radius, y: y - radius * 0.34,
                              width: radius * 2, height: radius * 0.68)
            context.fill(Path(ellipseIn: rect), with: .radialGradient(
                Gradient(colors: [spec.color.opacity(spec.alpha), .clear]),
                center: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: 0,
                endRadius: radius
            ))
        }

        // Land below the horizon. It has to be darker than the sky directly
        // above it, or the horizon line reads as a rendering seam rather than
        // as distance.
        let ground = CGRect(x: 0, y: horizonY, width: size.width, height: size.height - horizonY)
        context.fill(Path(ground), with: .linearGradient(
            Gradient(colors: [RestPalette.night, RestPalette.deepNight]),
            startPoint: CGPoint(x: 0, y: horizonY),
            endPoint: CGPoint(x: 0, y: size.height)
        ))

        // Vignette keeps the edges of a large display from glowing.
        context.fill(Path(full), with: .radialGradient(
            Gradient(colors: [.clear, RestPalette.deepNight.opacity(0.60)]),
            center: CGPoint(x: size.width / 2, y: size.height / 2),
            startRadius: min(size.width, size.height) * 0.28,
            endRadius: max(size.width, size.height) * 0.78
        ))
    }

    private struct Drift {
        let y: Double
        let radius: Double
        let period: Double
        let alpha: Double
        let color: Color
    }

    private static let drifts: [Drift] = [
        Drift(y: 0.70, radius: 0.30, period: 47, alpha: 0.15, color: RestPalette.sage),
        Drift(y: 0.76, radius: 0.24, period: 71, alpha: 0.13, color: RestPalette.glow),
        Drift(y: 0.64, radius: 0.20, period: 59, alpha: 0.07, color: RestPalette.mist),
    ]
}
