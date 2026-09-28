import XCTest
@testable import Clearspace

final class CalendarPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_467_200)
    private func eligible(daysAgo: Int = 60, writable: Bool = true, recurring: Bool = false,
                          detached: Bool = false, invitation: Bool = false) -> Bool {
        let end = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
        return CalendarCleanupPolicy.eligible(start: end.addingTimeInterval(-3600), end: end,
            writable: writable, recurring: recurring, detached: detached, invitation: invitation, now: now)
    }
    func testOnlyOldEventsInsideVisibleWindowQualify() {
        XCTAssertTrue(eligible())
        XCTAssertFalse(eligible(daysAgo: 30))
        XCTAssertFalse(eligible(daysAgo: 7))
        XCTAssertFalse(eligible(daysAgo: -1))
        XCTAssertFalse(eligible(daysAgo: 400))
    }
    func testProtectsSeriesInvitationsAndReadOnlyEvents() {
        XCTAssertFalse(eligible(writable: false))
        XCTAssertFalse(eligible(recurring: true))
        XCTAssertFalse(eligible(detached: true))
        XCTAssertFalse(eligible(invitation: true))
    }
    func testMalformedDateRangeDoesNotQualify() {
        XCTAssertFalse(CalendarCleanupPolicy.eligible(start: now, end: now.addingTimeInterval(-86400 * 60),
            writable: true, recurring: false, detached: false, invitation: false, now: now))
    }
    func testReviewSnapshotDetectsChangedNotes() {
        func item(_ notes: String) -> CalendarItem {
            CalendarItem(id: "a", title: "Test", calendarID: "c", calendarTitle: "Test calendar",
                start: now, end: now, modified: nil, location: nil, notes: notes, allDay: false)
        }
        XCTAssertNotEqual(item("Original"), item("Edited after review"))
    }
}
