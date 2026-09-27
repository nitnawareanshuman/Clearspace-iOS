import Foundation
import Photos
import UIKit
import Vision
import CryptoKit
import OSLog

/// Actor isolation keeps image analysis and resource reads off the UI actor.
actor LibraryScanner {
    struct Descriptor {
        let id: String
        let date: Date?
        let aspect: Double
        let screenshot: Bool
        let digest: String
        let hash: UInt64
        let print: VNFeaturePrintObservation?
    }
    private struct CachedSize {
        let snapshot: PhotoItem
        let bytes: Int64
    }
    private static let logger = Logger(subsystem: "Clearspace", category: "PhotoAnalysis")
    private var sizes: [String: CachedSize] = [:]

    private func measure(_ asset: PHAsset) async throws -> Int64 {
        let snapshot = PhotoItem(asset: asset)
        if snapshot.modified != nil, let cached = sizes[snapshot.id],
           SelectionPolicy.unchanged(cached.snapshot, current: snapshot) { return cached.bytes }
        let bytes = try await PhotoRequests.bytes(for: asset)
        try Task.checkCancellation()
        sizes[snapshot.id] = CachedSize(snapshot: snapshot, bytes: bytes)
        return bytes
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
        var blurryScores: [String: Double] = [:]
        var blurUnassessed = 0
        var unavailable = 0
        var similarityUnavailable = 0

        for index in 0..<assets.count {
            try Task.checkCancellation()
            let asset = assets.object(at: index)
            let item = PhotoItem(asset: asset)
            items[item.id] = item
            if item.screenshot { screenshotIDs.append(item.id) }
            do {
                let image = try await PhotoRequests.image(for: asset)
                if !item.screenshot {
                    let assessment = autoreleasepool { image.cgImage.flatMap { BlurAnalyzer.assess($0) } }
                    if let assessment {
                        if assessment.isLikelyBlurry { blurryScores[item.id] = assessment.variance }
                    } else { blurUnassessed += 1 }
                }
                let descriptor = try autoreleasepool { try Self.describe(image, item: item) }
                if descriptor.print == nil { similarityUnavailable += 1 }
                // Identical normalized previews can match anywhere in the library.
                var matchID = digestToID[descriptor.digest]
                var identical = matchID != nil
                if matchID == nil, !item.screenshot, let date = descriptor.date {
                    // Compare with group anchors, never a chain of progressively different shots.
                    for candidate in anchors.reversed().prefix(24) {
                        guard !candidate.screenshot, let otherDate = candidate.date,
                              abs(date.timeIntervalSince(otherDate)) <= 60,
                              abs(candidate.aspect - descriptor.aspect) < 0.025,
                              (candidate.hash ^ descriptor.hash).nonzeroBitCount <= 6 else { continue }
                        guard let feature = descriptor.print, let other = candidate.print else { continue }
                        var distance: Float = 1
                        do { try feature.computeDistance(&distance, to: other) }
                        catch {
                            Self.logger.error("Feature comparison failed: \(error.localizedDescription, privacy: .public)")
                            // Keep the image available for exact matching and later comparisons.
                            similarityUnavailable += 1
                            continue
                        }
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
            if index % 5 == 0 || index == assets.count - 1 {
                await progress("Checking photos & sharpness · \(index + 1) of \(assets.count)",
                    0.5 * Double(index + 1) / Double(max(1, assets.count)))
            }
        }
        try Task.checkCancellation()
        let groupIndices = buckets.indices.filter { buckets[$0].count > 1 }
        let sizeIDs = Set(screenshotIDs + Array(blurryScores.keys) + groupIndices.flatMap { buckets[$0] }).sorted()
        var unmeasured = 0
        // Serial resource streaming bounds memory and I/O. Only cleanup candidates need sizes.
        for (index, id) in sizeIDs.enumerated() {
            try Task.checkCancellation()
            if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject {
                do { items[id]?.bytes = try await measure(asset) }
                catch is CancellationError { throw CancellationError() }
                catch { unmeasured += 1 }
            } else { unmeasured += 1 }
            await progress("Measuring candidates · \(index + 1) of \(sizeIDs.count)",
                0.5 + 0.2 * Double(index + 1) / Double(max(1, sizeIDs.count)))
        }
        try Task.checkCancellation()
        let groups = groupIndices.map { index -> PhotoGroup in
            let photos = buckets[index].compactMap { items[$0] }
            return PhotoGroup(id: buckets[index][0], items: photos,
                keeperID: SelectionPolicy.keeper(in: photos), visuallyIdentical: allIdentical[index])
        }
        let videoAssets = PHAsset.fetchAssets(with: .video, options: options)
        var videos: [PhotoItem] = []
        for index in 0..<videoAssets.count {
            try Task.checkCancellation()
            let asset = videoAssets.object(at: index)
            var item = PhotoItem(asset: asset)
            do { item.bytes = try await measure(asset) }
            catch is CancellationError { throw CancellationError() }
            catch { unmeasured += 1 }
            videos.append(item)
            await progress("Measuring videos · \(index + 1) of \(videoAssets.count)",
                0.7 + 0.3 * Double(index + 1) / Double(max(1, videoAssets.count)))
        }
        try Task.checkCancellation()
        let accessible = Set(items.keys).union(videos.map(\.id))
        sizes = sizes.filter { accessible.contains($0.key) }
        return ScanResult(groups: groups.reversed(),
            screenshots: screenshotIDs.reversed().compactMap { items[$0] }, videos: VideoPolicy.sorted(videos),
            blurryPhotos: blurryScores.keys.sorted {
                let left = blurryScores[$0] ?? 0, right = blurryScores[$1] ?? 0
                return left == right ? $0 < $1 : left < right
            }.compactMap { items[$0] }, blurUnassessed: blurUnassessed, scanned: assets.count + videoAssets.count,
            unavailable: unavailable, similarityUnavailable: similarityUnavailable, unmeasured: unmeasured, seconds: Date().timeIntervalSince(start))
    }

    // Vision is optional: a failed feature print must never discard a valid pixel fingerprint.
    static func describe(_ image: UIImage, item: PhotoItem,
                         featurePrint: (CGImage) throws -> VNFeaturePrintObservation = LibraryScanner.featurePrint) throws -> Descriptor {
        guard let cg = image.cgImage else { throw CleanerError.unavailable }
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
            + ":\(item.width)x\(item.height):\(item.screenshot)"
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
        let observation: VNFeaturePrintObservation?
        do { observation = try featurePrint(cg) }
        catch {
            logger.error("Feature print failed; exact matching remains available: \(error.localizedDescription, privacy: .public)")
            observation = nil
        }
        return Descriptor(id: item.id, date: item.created,
            aspect: Double(item.width) / Double(max(1, item.height)), screenshot: item.screenshot, digest: digest, hash: hash, print: observation)
    }

    static func featurePrint(_ image: CGImage) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        // Keep revision 2's calibrated distance scale on both simulator and device.
        request.revision = VNGenerateImageFeaturePrintRequestRevision2
        #if targetEnvironment(simulator)
        // The simulator does not provide the same Vision accelerator path as an iPhone.
        request.usesCPUOnly = true
        #endif
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        guard let observation = request.results?.first else { throw CleanerError.unavailable }
        return observation
    }

}


extension PhotoItem {
    init(asset: PHAsset) {
        self.init(id: asset.localIdentifier, created: asset.creationDate,
            modified: asset.modificationDate, width: asset.pixelWidth, height: asset.pixelHeight,
            favorite: asset.isFavorite, screenshot: asset.mediaSubtypes.contains(.photoScreenshot),
            video: asset.mediaType == .video, duration: asset.duration, canDelete: asset.canPerform(.delete))
    }
}


