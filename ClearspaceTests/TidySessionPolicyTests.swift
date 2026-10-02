import XCTest
@testable import Clearspace

final class TidySessionPolicyTests: XCTestCase {
    private func item(_ id: String, created: Date? = nil, favorite: Bool = false,
                      screenshot: Bool = true, canDelete: Bool = true, video: Bool = false) -> PhotoItem {
        var result = PhotoItem(id: id, created: created, modified: nil, width: 300, height: 600,
                               favorite: favorite, screenshot: screenshot, bytes: 100)
        result.canDelete = canDelete
        result.video = video
        return result
    }

    func testBatchIsLimitedAndOldestFirst() {
        let screenshots = (0..<25).reversed().map {
            item("shot-\($0)", created: Date(timeIntervalSince1970: Double($0)))
        }
        let batch = TidySessionPolicy.candidates(from: ScanResult(screenshots: screenshots))
        XCTAssertEqual(batch.count, 10)
        XCTAssertEqual(batch.map(\.id), (0..<10).map { "shot-\($0)" })
    }

    func testFavoritesReadOnlyNonScreenshotsAndVideosAreSkipped() {
        let result = ScanResult(screenshots: [
            item("favorite", favorite: true), item("locked", canDelete: false),
            item("ordinary", screenshot: false), item("video", video: true), item("eligible")
        ])
        XCTAssertEqual(TidySessionPolicy.candidates(from: result).map(\.id), ["eligible"])
    }

    func testReviewedItemsStayOutOfTheNextBatchAndDuplicatesCountOnce() {
        let result = ScanResult(screenshots: [item("a"), item("b"), item("b"), item("c")])
        XCTAssertEqual(TidySessionPolicy.candidates(from: result, excluding: ["a", "b"]).map(\.id), ["c"])
    }

    func testMissingDatesComeLastAndTiesAreStable() {
        let date = Date(timeIntervalSince1970: 100)
        let result = ScanResult(screenshots: [item("unknown"), item("b", created: date), item("a", created: date)])
        XCTAssertEqual(TidySessionPolicy.candidates(from: result).map(\.id), ["a", "b", "unknown"])
    }

    func testEmptyLibraryHasNoSession() {
        XCTAssertTrue(TidySessionPolicy.candidates(from: ScanResult()).isEmpty)
    }
}
