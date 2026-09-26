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
    func testBulkSelectionKeepsOneCopyAndExcludesReadOnlyMedia() {
        var readOnly = item("read-only")
        readOnly.canDelete = false
        let a = item("a"), b = item("b")
        let group = PhotoGroup(id: "g", items: [a, b], keeperID: "a", visuallyIdentical: true)
        XCTAssertEqual(SelectionPolicy.safeSelection([a, b, readOnly], groups: [group]).map(\.id), ["b"])
        XCTAssertEqual(SelectionPolicy.safeSelection([a], groups: [group]).map(\.id), ["a"])
    }
    func testSavingsDoNotDoubleCountScreenshotsInSimilarGroups() {
        let a = item("a", bytes: 100), b = item("b", bytes: 200), cloud = item("cloud", bytes: nil)
        let group = PhotoGroup(id: "g", items: [a, b], keeperID: "a", visuallyIdentical: true)
        let result = ScanResult(groups: [group], screenshots: [a, b, cloud])
        XCTAssertEqual(result.screenshotCandidates.map(\.id), ["b", "cloud"])
        XCTAssertEqual(ByteSummary(result.cleanupCandidates).known, 200)
        XCTAssertEqual(ByteSummary(result.cleanupCandidates).unknown, 1)
        XCTAssertEqual(ByteSummary([b, b, cloud, cloud]).known, 200)
        XCTAssertEqual(ByteSummary([b, b, cloud, cloud]).unknown, 1)
    }
    func testChangedFavoriteInvalidatesReviewEvenWithoutModificationDate() {
        XCTAssertFalse(SelectionPolicy.unchanged(item("a"), current: item("a", favorite: true)))
        XCTAssertFalse(SelectionPolicy.unchanged(item("a"), current: item("a", width: 200)))
        XCTAssertFalse(SelectionPolicy.unchanged(item("a"), current: item("b")))
        XCTAssertTrue(SelectionPolicy.unchanged(item("a", bytes: nil), current: item("a", bytes: 100)))
    }
    func testReadOnlyDuplicatesNeverBecomeSuggestions() {
        var readOnly = item("b")
        readOnly.canDelete = false
        let group = PhotoGroup(id: "g", items: [item("a"), readOnly], keeperID: "a", visuallyIdentical: true)
        XCTAssertTrue(group.suggested.isEmpty)
    }
    func testPhotoRequestCompletesOnlyOnce() async throws {
        let gate = RequestGate<Int>()
        let value: Int = try await withCheckedThrowingContinuation { continuation in
            gate.attach(continuation)
            gate.finish(.success(42))
            gate.finish(.success(99))
            gate.finish(.failure(CancellationError()))
        }
        XCTAssertEqual(value, 42)
    }
    func testPhotoRequestCancellationBeforeContinuationIsAttached() async {
        let gate = RequestGate<Int>()
        gate.finish(.failure(CancellationError()))
        var cancelled = false
        gate.configure { cancelled = true }
        XCTAssertTrue(cancelled)
        do {
            let _: Int = try await withCheckedThrowingContinuation { gate.attach($0) }
            XCTFail("Cancelled request should throw")
        } catch { XCTAssertTrue(error is CancellationError) }
    }
}
