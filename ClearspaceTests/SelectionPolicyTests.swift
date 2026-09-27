import XCTest
import UIKit
@testable import Clearspace

final class SelectionPolicyTests: XCTestCase {
    private func item(_ id: String, favorite: Bool = false, width: Int = 100,
                      date: Date? = nil, bytes: Int64? = 20) -> PhotoItem {
        PhotoItem(id: id, created: date, modified: nil, width: width, height: 100,
                  favorite: favorite, screenshot: false, bytes: bytes)
    }
    func testConfirmedDeletionUpdatesOverlappingCategoriesOnce() {
        let a = item("a", bytes: 100), b = item("b", bytes: 200), c = item("c", bytes: 300)
        let group = PhotoGroup(id: "g", items: [a, b, c], keeperID: "a", visuallyIdentical: true)
        let original = ScanResult(groups: [group], screenshots: [a, b], videos: [c], scanned: 3)
        let updated = original.removing(["b"])
        XCTAssertEqual(updated.scanned, 2)
        XCTAssertEqual(updated.groups.first?.items.map(\.id), ["a", "c"])
        XCTAssertEqual(updated.screenshots.map(\.id), ["a"])
        XCTAssertEqual(updated.videos.map(\.id), ["c"])
        XCTAssertEqual(ByteSummary(updated.cleanupCandidates).known, 300)
        XCTAssertEqual(original.scanned, 3)
    }
    func testDeletingKeeperChoosesSurvivingKeeper() {
        let group = PhotoGroup(id: "g", items: [item("a"), item("b"), item("c")],
                               keeperID: "a", visuallyIdentical: false)
        let updated = ScanResult(groups: [group], scanned: 3).removing(["a"])
        XCTAssertEqual(updated.groups.first?.keeperID, "b")
        XCTAssertEqual(updated.suggestions.map(\.id), ["c"])
        XCTAssertFalse(SelectionPolicy.allows(["b", "c"], groups: updated.groups))
    }
    func testDeletingLastExtraRemovesGroupButPreservesScreenshotSurvivor() {
        let a = item("a"), b = item("b")
        let group = PhotoGroup(id: "g", items: [a, b], keeperID: "a", visuallyIdentical: true)
        let updated = ScanResult(groups: [group], screenshots: [a, b], scanned: 2).removing(["b"])
        XCTAssertTrue(updated.groups.isEmpty)
        XCTAssertEqual(updated.screenshots.map(\.id), ["a"])
        XCTAssertEqual(updated.scanned, 1)
    }
    func testRemovingVideoUpdatesUnknownSizeCountAndAllowsEmptyResult() {
        let result = ScanResult(videos: [item("video", bytes: nil)], scanned: 1, unmeasured: 1)
        let updated = result.removing(["video"])
        XCTAssertTrue(updated.videos.isEmpty)
        XCTAssertEqual(updated.scanned, 0)
        XCTAssertEqual(updated.unmeasured, 0)
        XCTAssertTrue(updated.cleanupCandidates.isEmpty)
        XCTAssertEqual(updated.removing(["video"]).scanned, 0)
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



final class PhotoAnalysisRegressionTests: XCTestCase {
    private func image(_ color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
            UIColor.black.setFill()
            context.fill(CGRect(x: 8, y: 12, width: 20, height: 32))
        }
    }
    private func item(_ id: String) -> PhotoItem {
        PhotoItem(id: id, created: nil, modified: nil, width: 80, height: 80,
                  favorite: false, screenshot: false)
    }
    func testIdenticalImagesKeepMatchingWhenVisionThrows() throws {
        let photo = image(.red)
        let a = try LibraryScanner.describe(photo, item: item("a")) { _ in throw CleanerError.unavailable }
        let b = try LibraryScanner.describe(photo, item: item("b")) { _ in throw CleanerError.unavailable }
        XCTAssertNil(a.print)
        XCTAssertNil(b.print)
        XCTAssertEqual(a.digest, b.digest)
        XCTAssertEqual(a.hash, b.hash)
    }
    func testVisionFailureDoesNotMakeDifferentImagesIdentical() throws {
        let a = try LibraryScanner.describe(image(.red), item: item("a")) { _ in throw CleanerError.unavailable }
        let b = try LibraryScanner.describe(image(.blue), item: item("b")) { _ in throw CleanerError.unavailable }
        XCTAssertNotEqual(a.digest, b.digest)
    }
    func testUnreadableImageStillFailsInsteadOfGettingAnEmptyFingerprint() {
        XCTAssertThrowsError(try LibraryScanner.describe(UIImage(), item: item("a")))
    }
    func testPartialAnalysisCannotBeReportedAsComplete() {
        XCTAssertFalse(ScanResult().analysisIncomplete)
        XCTAssertTrue(ScanResult(unavailable: 1).analysisIncomplete)
        XCTAssertTrue(ScanResult(similarityUnavailable: 1).analysisIncomplete)
    }
}


final class SwipePolicyTests: XCTestCase {
    private func photo(_ id: String, deletable: Bool = true) -> PhotoItem {
        PhotoItem(id: id, created: nil, modified: nil, width: 100, height: 100,
                  favorite: false, screenshot: true, bytes: 100, canDelete: deletable)
    }

    func testLastCopyCannotBeQueuedAcrossScreenshotAndSimilarCategories() {
        let a = photo("a"), b = photo("b")
        let groups = [PhotoGroup(id: "g", items: [a, b], keeperID: "a", visuallyIdentical: true)]
        XCTAssertNil(SwipePolicy.blockReason(.delete, item: a, selected: [], groups: groups))
        XCTAssertNotNil(SwipePolicy.blockReason(.delete, item: b, selected: ["a"], groups: groups))
        XCTAssertNil(SwipePolicy.blockReason(.keep, item: b, selected: ["a"], groups: groups))
    }

    func testReadOnlyPhotoCanBeKeptButNotQueued() {
        let item = photo("a", deletable: false)
        XCTAssertNotNil(SwipePolicy.blockReason(.delete, item: item, selected: [], groups: []))
        XCTAssertNil(SwipePolicy.blockReason(.keep, item: item, selected: [], groups: []))
    }

    func testKeepAndUndoRestoreExistingGridSelection() {
        let original: Set<String> = ["a", "b"]
        let afterKeep = SwipePolicy.applying(.keep, id: "a", to: original)
        XCTAssertEqual(afterKeep, ["b"])
        let entry = SwipeHistoryEntry(index: 0, id: "a", wasSelected: true)
        XCTAssertEqual(SwipePolicy.restoring(entry, in: afterKeep), original)
    }

    func testDeleteAndUndoPreserveOtherChoices() {
        let afterDelete = SwipePolicy.applying(.delete, id: "a", to: ["b"])
        XCTAssertEqual(afterDelete, ["a", "b"])
        let entry = SwipeHistoryEntry(index: 0, id: "a", wasSelected: false)
        XCTAssertEqual(SwipePolicy.restoring(entry, in: afterDelete), ["b"])
    }

    func testQueueingAlreadySelectedPhotoDoesNotDuplicateIt() {
        XCTAssertEqual(SwipePolicy.applying(.delete, id: "a", to: ["a"]), ["a"])
    }
}
