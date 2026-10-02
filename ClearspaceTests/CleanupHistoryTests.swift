import XCTest
@testable import Clearspace

final class CleanupHistoryTests: XCTestCase {
    @MainActor func testClearingHistoryPersistsAndCanStartAgain() {
        let name = "PipSweepTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let history = CleanupHistory(defaults: defaults)
        history.record(photos: 2, bytes: 4096)
        history.clear()
        XCTAssertTrue(history.receipts.isEmpty)
        XCTAssertTrue(CleanupHistory(defaults: defaults).receipts.isEmpty)
        history.record(contacts: 1)
        XCTAssertEqual(CleanupHistory(defaults: defaults).receipts.count, 1)
    }

    @MainActor func testConfirmedActivitySurvivesRelaunchWithoutInventedEventBytes() {
        let name = "ClearspaceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let history = CleanupHistory(defaults: defaults)
        XCTAssertTrue(history.receipts.isEmpty)
        history.record(photos: 2, videos: 1, bytes: 4096, unknownSizes: 1)
        history.record(events: 3)
        history.record(contacts: 1)
        history.record() // Empty cleanup is not activity.
        let restored = CleanupHistory(defaults: defaults)
        XCTAssertEqual(restored.receipts.count, 3)
        XCTAssertEqual(restored.receipts.reduce(0) { $0 + $1.itemCount }, 7)
        XCTAssertEqual(restored.receipts.reduce(Int64(0)) { $0 + $1.estimatedBytes }, 4096)
        XCTAssertEqual(restored.receipts.last?.unknownSizes, 1)
        XCTAssertEqual(restored.receipts.first?.contacts, 1)
    }
}
