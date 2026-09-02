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

/// The break palette, chosen from the visual-ergonomics literature rather
/// than from branding.
///
/// The overlay fills a whole display for the length of a break, so it is the
/// one surface where eye comfort outranks the indigo identity. Three findings
/// shape it:
///
/// - **Match the room, do not fight it.** Visual ergonomics puts the
///   screen-to-surround luminance ratio at roughly 3:1 or under; the strain
///   comes from the size of the adaptation jump, in either direction. So there
///   are two palettes, and the overlay follows the system appearance instead
///   of always going near-black.
/// - **Light beats dark for most eyes.** A dark field dilates the pupil and
///   admits more optical aberration, and light-on-dark text haloes for the
///   30-50% of adults with astigmatism. Dark only wins in a genuinely dim room,
///   which is exactly when the system is in dark appearance.
/// - **Light green specifically.** A 2025 reading study found a light green
///   ground raised pupil diameter (a marker of *lower* fatigue), lowered
///   negative affect, and improved reading performance against white.
///
/// Note what is deliberately *not* claimed here: blue light. A 2023 Cochrane
/// review of 17 trials found blue-filtering lenses make no reliable difference
/// to eye strain, so "avoid blue" is not the reason this palette is green.
struct RestPalette {
    let skyTop: Color
    let skyMid: Color
    let skyLow: Color
    let landTop: Color
    let landBottom: Color
    /// The horizon wash. Soft, never a bright bloom.
    let glow: Color
    /// The drifting cloud banks.
    let drift: Color
    /// Dots, symbols, the gaze mark.
    let accent: Color
    /// Body copy. Never pure white or pure black.
    let text: Color
    /// The completion mark.
    let success: Color
    let vignette: Color

    /// Daylight: a soft light green, close in luminance to a lit room and to a
    /// light-appearance desktop, so the break is a change of scene rather than
    /// a jolt.
    static let light = RestPalette(
        skyTop: Color(red: 0.910, green: 0.941, blue: 0.894),
        skyMid: Color(red: 0.863, green: 0.910, blue: 0.839),
        skyLow: Color(red: 0.792, green: 0.863, blue: 0.761),
        landTop: Color(red: 0.722, green: 0.808, blue: 0.690),
        landBottom: Color(red: 0.639, green: 0.741, blue: 0.612),
        glow: Color(red: 0.980, green: 0.965, blue: 0.878),
        drift: Color(red: 0.659, green: 0.769, blue: 0.627),
        accent: Color(red: 0.239, green: 0.396, blue: 0.278),
        text: Color(red: 0.114, green: 0.188, blue: 0.137),
        success: Color(red: 0.153, green: 0.416, blue: 0.271),
        vignette: Color(red: 0.545, green: 0.667, blue: 0.522)
    )

    /// Night: the dim room case, where a dark field genuinely is the smaller
    /// adaptation jump.
    static let dark = RestPalette(
        skyTop: Color(red: 0.047, green: 0.078, blue: 0.063),
        skyMid: Color(red: 0.071, green: 0.145, blue: 0.114),
        skyLow: Color(red: 0.113, green: 0.243, blue: 0.188),
        landTop: Color(red: 0.047, green: 0.078, blue: 0.063),
        landBottom: Color(red: 0.024, green: 0.043, blue: 0.035),
        glow: Color(red: 0.678, green: 0.827, blue: 0.694),
        drift: Color(red: 0.251, green: 0.439, blue: 0.337),
        accent: Color(red: 0.549, green: 0.749, blue: 0.627),
        text: Color(red: 0.863, green: 0.910, blue: 0.863),
        success: Color(red: 0.541, green: 0.792, blue: 0.678),
        vignette: Color(red: 0.024, green: 0.043, blue: 0.035)
    )
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
    var palette: RestPalette

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

        // Sky, easing down into a lit horizon. Every colour here must be fully
        // opaque - the overlay covers the user's screen, and anything
        // translucent leaks their work through it.
        context.fill(Path(full), with: .linearGradient(
            Gradient(colors: [palette.skyTop, palette.skyMid, palette.skyLow]),
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
                palette.glow.opacity(0.26),
                palette.drift.opacity(0.16),
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
                Gradient(colors: [(spec.warm ? palette.glow : palette.drift).opacity(spec.alpha), .clear]),
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
            Gradient(colors: [palette.landTop, palette.landBottom]),
            startPoint: CGPoint(x: 0, y: horizonY),
            endPoint: CGPoint(x: 0, y: size.height)
        ))

        // Vignette keeps the edges of a large display from glowing.
        context.fill(Path(full), with: .radialGradient(
            Gradient(colors: [.clear, palette.vignette.opacity(0.55)]),
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
        /// Whether this bank picks up the horizon colour rather than the
        /// cooler drift colour.
        let warm: Bool
    }

    private static let drifts: [Drift] = [
        Drift(y: 0.70, radius: 0.30, period: 47, alpha: 0.15, warm: false),
        Drift(y: 0.76, radius: 0.24, period: 71, alpha: 0.13, warm: true),
        Drift(y: 0.64, radius: 0.20, period: 59, alpha: 0.07, warm: false),
    ]
}
