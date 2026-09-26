import Foundation

struct PhotoItem: Identifiable {
    let id: String
    let created: Date?
    let modified: Date?
    let width: Int
    let height: Int
    let favorite: Bool
    let screenshot: Bool
    var video = false
    var duration: TimeInterval = 0
    var bytes: Int64?
    var pixels: Int64 { Int64(width) * Int64(height) }
}

struct PhotoGroup: Identifiable {
    let id: String
    var items: [PhotoItem]
    let keeperID: String
    let visuallyIdentical: Bool
    var suggested: [PhotoItem] { items.filter { $0.id != keeperID && !$0.favorite } }
}

struct ByteSummary {
    let known: Int64
    let unknown: Int
    init(_ items: [PhotoItem]) {
        known = items.compactMap(\.bytes).reduce(0, +)
        unknown = items.filter { $0.bytes == nil }.count
    }
    var label: String {
        if unknown > 0 && known == 0 { return "Size unavailable" }
        let size = ByteCountFormatter.string(fromByteCount: known, countStyle: .file)
        return unknown > 0 ? "\(size) + unknown" : size
    }
}

struct ScanResult {
    var groups: [PhotoGroup] = []
    var screenshots: [PhotoItem] = []
    var videos: [PhotoItem] = []
    var scanned = 0
    var unavailable = 0
    var unmeasured = 0
    var seconds: Double = 0
    var suggestions: [PhotoItem] { groups.flatMap(\.suggested) }
}

struct StorageSnapshot {
    let total: Int64
    let free: Int64
    var used: Int64 { max(0, total - free) }
    var fraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
    static func read() throws -> StorageSnapshot {
        let values = try URL(fileURLWithPath: NSHomeDirectory()).resourceValues(
            forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        guard let total = values.volumeTotalCapacity, let free = values.volumeAvailableCapacity else {
            throw CleanerError.storageUnavailable
        }
        return StorageSnapshot(total: Int64(total), free: Int64(free))
    }
}

struct ReviewDraft: Identifiable {
    let id = UUID()
    let epoch: Int
    let items: [PhotoItem]
}

enum CleanerError: LocalizedError {
    case timedOut, unavailable, staleReview, storageUnavailable, noAccess
    var errorDescription: String? {
        switch self {
        case .timedOut: return "A photo took too long to load. Try scanning again."
        case .unavailable: return "This photo is not available on this device."
        case .staleReview: return "Your photo library changed. Scan again and review a fresh selection."
        case .storageUnavailable: return "Device storage could not be read. Try again."
        case .noAccess: return "Photos access is required. You can change access in Settings."
        }
    }
}

/// Pure rules shared by the scanner and tests. A suggestion is never a deletion decision.
enum SelectionPolicy {
    static func keeper(in items: [PhotoItem]) -> String {
        items.sorted {
            if $0.favorite != $1.favorite { return $0.favorite }
            if $0.pixels != $1.pixels { return $0.pixels > $1.pixels }
            if $0.created != $1.created { return ($0.created ?? .distantPast) > ($1.created ?? .distantPast) }
            return $0.id < $1.id
        }.first?.id ?? ""
    }
    static func allows(_ selection: Set<String>, groups: [PhotoGroup]) -> Bool {
        groups.allSatisfy { group in group.items.contains { !selection.contains($0.id) } }
    }
    static func unique(_ items: [PhotoItem]) -> [PhotoItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }
    static func isNear(aspectA: Double, aspectB: Double, hashA: UInt64, hashB: UInt64, distance: Float) -> Bool {
        abs(aspectA - aspectB) < 0.025 && (hashA ^ hashB).nonzeroBitCount <= 6 && distance <= 0.18
    }
}

/// Known sizes sort descending; cloud-only or unreadable sizes stay visible at the end.
enum VideoPolicy {
    static func sorted(_ items: [PhotoItem]) -> [PhotoItem] {
        items.sorted {
            if $0.bytes != $1.bytes { return ($0.bytes ?? -1) > ($1.bytes ?? -1) }
            return $0.id < $1.id
        }
    }
}
