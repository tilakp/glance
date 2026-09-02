import Foundation

/// Counts breaks taken today. Deliberately the only statistic Glance keeps:
/// enough for a sense of rhythm, not enough to become a guilt tracker.
final class SessionLog: ObservableObject {
    static let shared = SessionLog()

    private let store = UserDefaults.standard
    private let countKey = "breaksTakenCount"
    private let dayKey = "breaksTakenDay"

    /// Computed rather than stored: a menu bar app runs for days, and a value
    /// cached at launch would keep showing yesterday's count after midnight
    /// until the next break happened to land.
    var breaksToday: Int {
        isToday ? store.integer(forKey: countKey) : 0
    }

    private init() {}

    private var isToday: Bool {
        guard let stamp = store.object(forKey: dayKey) as? Date else { return false }
        return Calendar.current.isDateInToday(stamp)
    }

    func recordCompletedBreak() {
        let next = isToday ? store.integer(forKey: countKey) + 1 : 1
        objectWillChange.send()
        store.set(next, forKey: countKey)
        store.set(Date(), forKey: dayKey)
    }
}
