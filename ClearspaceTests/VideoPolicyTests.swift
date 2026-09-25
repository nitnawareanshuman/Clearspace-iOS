import XCTest
@testable import Clearspace

final class VideoPolicyTests: XCTestCase {
    func testDescendingSizeWithUnknownLastAndStableTies() {
        func video(_ id: String, bytes: Int64?) -> PhotoItem {
            PhotoItem(id: id, created: nil, modified: nil, width: 1920, height: 1080,
                favorite: false, screenshot: false, video: true, duration: 60, bytes: bytes)
        }
        let items = [video("cloud", bytes: nil), video("b", bytes: 100), video("large", bytes: 500),
                     video("zero", bytes: 0), video("a", bytes: 100)]
        XCTAssertEqual(VideoPolicy.sorted(items).map(\.id), ["large", "a", "b", "zero", "cloud"])
        XCTAssertEqual(ByteSummary(items).unknown, 1)
        XCTAssertEqual(ByteSummary(items).known, 700)
    }
}
