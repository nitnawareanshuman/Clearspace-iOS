import XCTest
import UIKit
import CoreImage
@testable import Clearspace

final class BlurAnalyzerTests: XCTestCase {
    private func checkerboard() -> [UInt8] {
        (0..<(256 * 256)).map { index in
            ((index % 256 / 16) + (index / 256 / 16)) % 2 == 0 ? 30 : 220
        }
    }

    func testSharpEdgesAreNotBlurry() throws {
        let assessment = try XCTUnwrap(BlurAnalyzer.assess(pixels: checkerboard(), width: 256, height: 256))
        XCTAssertFalse(assessment.isLikelyBlurry)
    }

    func testGaussianBlurIsSuggested() throws {
        let data = Data(checkerboard())
        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
        let image = try XCTUnwrap(CGImage(width: 256, height: 256, bitsPerComponent: 8,
            bitsPerPixel: 8, bytesPerRow: 256, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let input = CIImage(cgImage: image)
        let output = input.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 4.0])
        let blurred = try XCTUnwrap(CIContext(options: [.useSoftwareRenderer: true])
            .createCGImage(output, from: input.extent))
        XCTAssertTrue(try XCTUnwrap(BlurAnalyzer.assess(blurred)).isLikelyBlurry)
        XCTAssertFalse(try XCTUnwrap(BlurAnalyzer.assess(image)).isLikelyBlurry)
    }

    func testSharpSubjectAgainstSoftBackgroundIsProtected() throws {
        var pixels = (0..<(256 * 256)).map { UInt8(40 + ($0 % 256) / 2) }
        // A small, sharply focused subject: global variance alone would flag it.
        for y in 100..<116 {
            for x in 100..<116 { pixels[y * 256 + x] = (x / 4) % 2 == 0 ? 50 : 170 }
        }
        let assessment = try XCTUnwrap(BlurAnalyzer.assess(pixels: pixels, width: 256, height: 256))
        XCTAssertLessThan(assessment.variance, 80)
        XCTAssertGreaterThanOrEqual(assessment.sharpestRegion, 160)
        XCTAssertFalse(assessment.isLikelyBlurry)
    }

    func testBlankLowContrastTinyAndMalformedImagesAreUnassessable() {
        XCTAssertNil(BlurAnalyzer.assess(pixels: [UInt8](repeating: 128, count: 65536), width: 256, height: 256))
        let lowContrast = (0..<65536).map { UInt8(126 + $0 % 4) }
        XCTAssertNil(BlurAnalyzer.assess(pixels: lowContrast, width: 256, height: 256))
        XCTAssertNil(BlurAnalyzer.assess(pixels: [], width: 256, height: 256))
        XCTAssertNil(BlurAnalyzer.assess(pixels: [UInt8](repeating: 100, count: 32 * 32), width: 32, height: 32))
    }

    private func item(_ id: String, favorite: Bool = false, bytes: Int64? = 100) -> PhotoItem {
        PhotoItem(id: id, created: nil, modified: nil, width: 256, height: 256,
            favorite: favorite, screenshot: false, bytes: bytes)
    }

    func testBlurSuggestionsRespectFavoritesReadOnlyAndKeepOne() {
        let a = item("a"), b = item("b"), favorite = item("favorite", favorite: true)
        var readOnly = item("readOnly")
        readOnly.canDelete = false
        let group = PhotoGroup(id: "group", items: [a, b], keeperID: a.id, visuallyIdentical: true)
        let result = ScanResult(groups: [group], blurryPhotos: [a, b, favorite, readOnly])
        XCTAssertEqual(result.blurryCandidates.map(\.id), [b.id])
        XCTAssertEqual(ByteSummary(result.cleanupCandidates).known, 100)
    }

    func testDeletionReconcilesBlurAndOverlappingGroupsOnce() {
        let a = item("a"), b = item("b", bytes: nil), c = item("c")
        let group = PhotoGroup(id: "group", items: [a, b], keeperID: a.id, visuallyIdentical: true)
        let result = ScanResult(groups: [group], blurryPhotos: [b, c], scanned: 3, unmeasured: 1)
        XCTAssertEqual(ByteSummary(result.cleanupCandidates).known, 100)
        XCTAssertEqual(ByteSummary(result.cleanupCandidates).unknown, 1)
        let updated = result.removing([b.id])
        XCTAssertTrue(updated.groups.isEmpty)
        XCTAssertEqual(updated.blurryPhotos.map(\.id), [c.id])
        XCTAssertEqual(updated.scanned, 2)
        XCTAssertEqual(updated.unmeasured, 0)
        XCTAssertTrue(updated.removing([c.id]).blurryPhotos.isEmpty)
        XCTAssertEqual(result.blurryPhotos.count, 2)
    }
}
