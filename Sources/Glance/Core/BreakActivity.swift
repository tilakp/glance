import Foundation

/// A prompt shown during a break. Rotating these keeps the overlay from
/// becoming wallpaper the user stops reading.
struct BreakActivity: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String

    static let all: [BreakActivity] = [
        BreakActivity(
            id: "distance",
            title: "Look into the distance",
            detail: "Find something at least 20 feet away.",
            symbol: "mountain.2"
        ),
        BreakActivity(
            id: "window",
            title: "Find a window",
            detail: "Let your eyes rest on something outside.",
            symbol: "window.awning"
        ),
        BreakActivity(
            id: "blink",
            title: "Blink slowly",
            detail: "A few complete, unhurried blinks.",
            symbol: "eye"
        ),
        BreakActivity(
            id: "horizon",
            title: "Find the horizon",
            detail: "Look toward the farthest point you can see.",
            symbol: "sun.horizon"
        ),
        BreakActivity(
            id: "movement",
            title: "Shift your gaze",
            detail: "Slowly move your eyes left, then right.",
            symbol: "arrow.left.and.right"
        ),
        BreakActivity(
            id: "relax",
            title: "Unclench",
            detail: "Soften your jaw. Drop your shoulders.",
            symbol: "figure.mind.and.body"
        ),
    ]

    static func enabled(from ids: [String]) -> [BreakActivity] {
        let picked = all.filter { ids.contains($0.id) }
        return picked.isEmpty ? [all[0]] : picked
    }
}
