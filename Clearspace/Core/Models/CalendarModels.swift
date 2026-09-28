import Foundation

struct CalendarItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let calendarID: String
    let calendarTitle: String
    let start: Date
    let end: Date
    let modified: Date?
    let location: String?
    let notes: String?
    let allDay: Bool
}

enum CalendarCleanupPolicy {
    static func eligible(start: Date, end: Date, writable: Bool, recurring: Bool,
                         detached: Bool, invitation: Bool, now: Date = Date()) -> Bool {
        let calendar = Calendar.current
        guard let lower = calendar.date(byAdding: .year, value: -1, to: now),
              let cutoff = calendar.date(byAdding: .day, value: -30, to: now) else { return false }
        return writable && !recurring && !detached && !invitation
            && start >= lower && end >= start && end < cutoff
    }
}

enum CalendarCleanupError: LocalizedError {
    case access, stale
    var errorDescription: String? {
        switch self {
        case .access: return "Full Calendar access is required to review and remove old events."
        case .stale: return "The calendar changed. Scan again and review a fresh selection before deleting."
        }
    }
}
