import Foundation
import CoreGraphics

/// A conservative suggestion, never a reason to delete without review.
/// Thresholds use 8-bit luminance at a fixed 256-pixel longest edge.
enum BlurAnalyzer {
    private static let regionSide = 8
    struct Assessment {
        let variance: Double
        let sharpestRegion: Double
        var isLikelyBlurry: Bool { variance < 350 && sharpestRegion < 800 }
    }

    static func assess(_ image: CGImage) -> Assessment? {
        guard max(image.width, image.height) >= 256 else { return nil }
        let scale = min(1, 256.0 / Double(max(image.width, image.height)))
        let width = Int(Double(image.width) * scale)
        let height = Int(Double(image.height) * scale)
        guard min(width, height) >= 64 else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { return nil }
        return assess(pixels: pixels, width: width, height: height)
    }

    /// Nil means unassessable, not sharp: flat skies, blank frames and tiny images
    /// do not contain enough evidence. Two overlapping grids protect an in-focus
    /// subject without diluting its edges into an intentionally soft background.
    static func assess(pixels: [UInt8], width: Int, height: Int) -> Assessment? {
        guard width >= 64, height >= 64, width <= 256, height <= 256,
              pixels.count == width * height else { return nil }
        let count = Double(pixels.count)
        let mean = pixels.reduce(0.0) { $0 + Double($1) } / count
        let contrast = pixels.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / count
        guard contrast >= 100 else { return nil }

        let primaryCount = regionSide * regionSide
        let shiftedSide = regionSide + 1
        let regionCount = primaryCount + shiftedSide * shiftedSide
        var sums = [Double](repeating: 0, count: regionCount)
        var squares = [Double](repeating: 0, count: regionCount)
        var counts = [Int](repeating: 0, count: regionCount)
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let i = y * width + x
                let edge = Double(Int(pixels[i - 1]) + Int(pixels[i + 1])
                    + Int(pixels[i - width]) + Int(pixels[i + width]) - 4 * Int(pixels[i]))
                let region = min(regionSide - 1, y * regionSide / height) * regionSide
                    + min(regionSide - 1, x * regionSide / width)
                sums[region] += edge
                squares[region] += edge * edge
                counts[region] += 1
                // The half-cell offset keeps a subject on a grid boundary from
                // being divided among four unrelated background regions.
                let shifted = primaryCount
                    + ((y * regionSide + height / 2) / height) * shiftedSide
                    + (x * regionSide + width / 2) / width
                sums[shifted] += edge
                squares[shifted] += edge * edge
                counts[shifted] += 1
            }
        }
        let n = Double(counts.prefix(primaryCount).reduce(0, +))
        let average = sums.prefix(primaryCount).reduce(0, +) / n
        let variance = max(0, squares.prefix(primaryCount).reduce(0, +) / n - average * average)
        let sharpest = counts.indices.map { index -> Double in
            let n = Double(max(1, counts[index]))
            let mean = sums[index] / n
            return max(0, squares[index] / n - mean * mean)
        }.max() ?? 0
        return Assessment(variance: variance, sharpestRegion: sharpest)
    }
}
