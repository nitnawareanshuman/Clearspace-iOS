import XCTest
@testable import Clearspace

final class SelectionPolicyTests: XCTestCase {
    private func item(_ id: String, favorite: Bool = false, width: Int = 100,
                      date: Date? = nil, bytes: Int64? = 20) -> PhotoItem {
        PhotoItem(id: id, created: date, modified: nil, width: width, height: 100,
                  favorite: favorite, screenshot: false, bytes: bytes)
    }
    func testFavoriteIsKeptAheadOfHigherResolution() {
        XCTAssertEqual(SelectionPolicy.keeper(in: [item("large", width: 1000), item("favorite", favorite: true)]), "favorite")
    }
    func testResolutionThenRecencyChooseKeeper() {
        XCTAssertEqual(SelectionPolicy.keeper(in: [item("small"), item("large", width: 200)]), "large")
        XCTAssertEqual(SelectionPolicy.keeper(in: [item("old", date: .distantPast), item("new", date: .distantFuture)]), "new")
    }
    func testKeeperTieIsDeterministic() {
        XCTAssertEqual(SelectionPolicy.keeper(in: [item("b"), item("a")]), "a")
    }
    func testCannotSelectWholeGroupButCanChooseAnotherKeeper() {
        let group = PhotoGroup(id: "a", items: [item("a"), item("b")], keeperID: "a", visuallyIdentical: false)
        XCTAssertFalse(SelectionPolicy.allows(["a", "b"], groups: [group]))
        XCTAssertTrue(SelectionPolicy.allows(["a"], groups: [group]))
        XCTAssertTrue(SelectionPolicy.allows([], groups: [group]))
    }
    func testSuggestionsExcludeAllFavoritesAndKeeper() {
        let group = PhotoGroup(id: "a", items: [item("a", favorite: true), item("b", favorite: true), item("c")],
                               keeperID: "a", visuallyIdentical: false)
        XCTAssertEqual(group.suggested.map(\.id), ["c"])
    }
    func testReviewDeduplicatesStableIdentifiers() {
        XCTAssertEqual(SelectionPolicy.unique([item("a"), item("b"), item("a")]).map(\.id), ["a", "b"])
    }
    func testUnknownSizeIsNotTreatedAsZeroBytes() {
        let summary = ByteSummary([item("a", bytes: 30), item("b", bytes: nil)])
        XCTAssertEqual(summary.known, 30)
        XCTAssertEqual(summary.unknown, 1)
        XCTAssertEqual(ByteSummary([item("b", bytes: nil)]).label, "Size unavailable")
    }
    func testSimilarityNeedsAllThreeSignals() {
        XCTAssertTrue(SelectionPolicy.isNear(aspectA: 1, aspectB: 1, hashA: 0, hashB: 1, distance: 0.1))
        XCTAssertFalse(SelectionPolicy.isNear(aspectA: 1, aspectB: 1.5, hashA: 0, hashB: 0, distance: 0))
        XCTAssertFalse(SelectionPolicy.isNear(aspectA: 1, aspectB: 1, hashA: 0, hashB: 127, distance: 0))
        XCTAssertFalse(SelectionPolicy.isNear(aspectA: 1, aspectB: 1, hashA: 0, hashB: 0, distance: 0.3))
    }
    func testStorageUsageCannotBeNegative() {
        XCTAssertEqual(StorageSnapshot(total: 100, free: 120).used, 0)
        XCTAssertEqual(StorageSnapshot(total: 0, free: 0).fraction, 0)
    }
}
