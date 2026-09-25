import Foundation
import Photos
import UIKit
import Vision
import CryptoKit

/// Actor isolation keeps image analysis and resource reads off the UI actor.
actor LibraryScanner {
    private struct Descriptor {
        let id: String
        let date: Date?
        let aspect: Double
        let digest: String
        let hash: UInt64
        let print: VNFeaturePrintObservation
    }
    func scan(progress: @escaping @Sendable (String, Double) async -> Void) async throws -> ScanResult {
        let start = Date()
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.includeHiddenAssets = false
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        var items: [String: PhotoItem] = [:]
        var buckets: [[String]] = []
        var bucketForID: [String: Int] = [:]
        var digestToID: [String: String] = [:]
        var anchors: [Descriptor] = []
        var allIdentical: [Bool] = []
        var screenshotIDs: [String] = []
        var unavailable = 0

        for index in 0..<assets.count {
            try Task.checkCancellation()
            let asset = assets.object(at: index)
            let item = PhotoItem(id: asset.localIdentifier, created: asset.creationDate,
                modified: asset.modificationDate, width: asset.pixelWidth, height: asset.pixelHeight,
                favorite: asset.isFavorite, screenshot: asset.mediaSubtypes.contains(.photoScreenshot))
            items[item.id] = item
            if item.screenshot { screenshotIDs.append(item.id) }
            else {
                do {
                    let image = try await PhotoRequests.image(for: asset)
                    let descriptor = try autoreleasepool { try describe(image, item: item) }
                    // Identical normalized previews can match anywhere in the library.
                    var matchID = digestToID[descriptor.digest]
                    var identical = matchID != nil
                    if matchID == nil, let date = descriptor.date {
                        // Compare with group anchors, never a chain of progressively different shots.
                        for candidate in anchors.reversed().prefix(24) {
                            guard let otherDate = candidate.date,
                                  abs(date.timeIntervalSince(otherDate)) <= 60,
                                  abs(candidate.aspect - descriptor.aspect) < 0.025,
                                  (candidate.hash ^ descriptor.hash).nonzeroBitCount <= 6 else { continue }
                            var distance: Float = 1
                            try descriptor.print.computeDistance(&distance, to: candidate.print)
                            if SelectionPolicy.isNear(aspectA: descriptor.aspect, aspectB: candidate.aspect,
                                hashA: descriptor.hash, hashB: candidate.hash, distance: distance) {
                                matchID = candidate.id
                                identical = false
                                break
                            }
                        }
                    }
                    if let matchID, let bucket = bucketForID[matchID] {
                        buckets[bucket].append(item.id)
                        bucketForID[item.id] = bucket
                        allIdentical[bucket] = allIdentical[bucket] && identical
                    } else {
                        bucketForID[item.id] = buckets.count
                        buckets.append([item.id])
                        allIdentical.append(true)
                        anchors.append(descriptor)
                        if anchors.count > 24 { anchors.removeFirst() }
                    }
                    // Retain only an ID per digest; feature prints stay in the bounded 24-anchor window.
                    if digestToID[descriptor.digest] == nil { digestToID[descriptor.digest] = descriptor.id }
                } catch is CancellationError { throw CancellationError() }
                catch { unavailable += 1 }
            }
            if index % 5 == 0 || index == assets.count - 1 {
                await progress("Scanning photos · \(index + 1) of \(assets.count)",
                    0.7 * Double(index + 1) / Double(max(1, assets.count)))
            }
        }
        try Task.checkCancellation()
        let groupIndices = buckets.indices.filter { buckets[$0].count > 1 }
        let sizeIDs = Set(screenshotIDs + groupIndices.flatMap { buckets[$0] }).sorted()
        var unmeasured = 0
        // Serial resource streaming bounds memory and I/O. Only cleanup candidates need sizes.
        for (index, id) in sizeIDs.enumerated() {
            try Task.checkCancellation()
            if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject {
                do { items[id]?.bytes = try await PhotoRequests.bytes(for: asset) }
                catch is CancellationError { throw CancellationError() }
                catch { unmeasured += 1 }
            } else { unmeasured += 1 }
            await progress("Measuring candidates · \(index + 1) of \(sizeIDs.count)",
                0.7 + 0.3 * Double(index + 1) / Double(max(1, sizeIDs.count)))
        }
        try Task.checkCancellation()
        let groups = groupIndices.map { index -> PhotoGroup in
            let photos = buckets[index].compactMap { items[$0] }
            return PhotoGroup(id: buckets[index][0], items: photos,
                keeperID: SelectionPolicy.keeper(in: photos), visuallyIdentical: allIdentical[index])
        }
        return ScanResult(groups: groups.reversed(),
            screenshots: screenshotIDs.reversed().compactMap { items[$0] }, scanned: assets.count,
            unavailable: unavailable, unmeasured: unmeasured, seconds: Date().timeIntervalSince(start))
    }

    private func describe(_ image: UIImage, item: PhotoItem) throws -> Descriptor {
        guard let cg = image.cgImage else { throw CleanerError.unavailable }
        let request = VNGenerateImageFeaturePrintRequest()
        // Pin the revision: distance scales must not change with the OS default.
        request.revision = VNGenerateImageFeaturePrintRequestRevision2
        try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
        guard let print = request.results?.first else { throw CleanerError.unavailable }
        let side = 128
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard rendered else { throw CleanerError.unavailable }
        // Include aspect ratio: stretching unlike aspect ratios must not create exact-preview groups.
        let digest = SHA256.hash(data: Data(pixels)).map { String(format: "%02x", $0) }.joined()
            + ":\(item.width)x\(item.height)"
        var gray = [UInt8](repeating: 0, count: 9 * 8)
        let grayRendered = gray.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: 9, height: 8,
                bitsPerComponent: 8, bytesPerRow: 9, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: 9, height: 8))
            return true
        }
        guard grayRendered else { throw CleanerError.unavailable }
        var hash: UInt64 = 0
        for row in 0..<8 { for column in 0..<8 {
            if gray[row * 9 + column] > gray[row * 9 + column + 1] {
                hash |= UInt64(1) << (row * 8 + column)
            }
        } }
        return Descriptor(id: item.id, date: item.created,
            aspect: Double(item.width) / Double(max(1, item.height)), digest: digest, hash: hash, print: print)
    }
}
