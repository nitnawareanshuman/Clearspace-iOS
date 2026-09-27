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
    var canDelete = true
    var pixels: Int64 { Int64(width) * Int64(height) }
}

struct PhotoGroup: Identifiable {
    let id: String
    var items: [PhotoItem]
    let keeperID: String
    let visuallyIdentical: Bool
    var suggested: [PhotoItem] { items.filter { $0.id != keeperID && !$0.favorite && $0.canDelete } }
}

struct ByteSummary {
    let known: Int64
    let unknown: Int
    init(_ items: [PhotoItem]) {
        let unique = SelectionPolicy.unique(items)
        known = unique.compactMap(\.bytes).reduce(0, +)
        unknown = unique.filter { $0.bytes == nil }.count
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
    var similarityUnavailable = 0
    var unmeasured = 0
    var analysisIncomplete: Bool { unavailable > 0 || similarityUnavailable > 0 }
    var seconds: Double = 0
    /// Reconcile only a confirmed deletion; all remaining byte estimates stay valid.
    func removing(_ ids: Set<String>) -> ScanResult {
        var updated = self
        let removedItems = SelectionPolicy.unique(groups.flatMap(\.items) + screenshots + videos)
            .filter { ids.contains($0.id) }
        updated.groups = groups.compactMap { group in
            let remaining = group.items.filter { !ids.contains($0.id) }
            guard remaining.count > 1 else { return nil }
            return PhotoGroup(id: group.id, items: remaining,
                keeperID: remaining.contains { $0.id == group.keeperID }
                    ? group.keeperID : SelectionPolicy.keeper(in: remaining),
                visuallyIdentical: group.visuallyIdentical)
        }
        updated.screenshots.removeAll { ids.contains($0.id) }
        updated.videos.removeAll { ids.contains($0.id) }
        updated.scanned = max(0, scanned - removedItems.count)
        updated.unmeasured = max(0, unmeasured - removedItems.filter { $0.bytes == nil }.count)
        return updated
    }
    var suggestions: [PhotoItem] { groups.flatMap(\.suggested) }
    var screenshotCandidates: [PhotoItem] { SelectionPolicy.safeSelection(screenshots, groups: groups) }
    var videoCandidates: [PhotoItem] { videos.filter(\.canDelete) }
    var cleanupCandidates: [PhotoItem] {
        SelectionPolicy.safeSelection(suggestions + screenshotCandidates + videoCandidates, groups: groups)
    }
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
    let kept: [PhotoItem]
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
    /// Bulk actions obey the same keep-one rule as individual taps, even across categories.
    static func safeSelection(_ items: [PhotoItem], groups: [PhotoGroup]) -> [PhotoItem] {
        let candidates = unique(items).filter(\.canDelete)
        var ids = Set(candidates.map(\.id))
        for group in groups where !group.items.isEmpty && group.items.allSatisfy({ ids.contains($0.id) }) {
            ids.remove(group.keeperID)
        }
        return candidates.filter { ids.contains($0.id) }
    }

    static func unchanged(_ snapshot: PhotoItem, current: PhotoItem) -> Bool {
        snapshot.id == current.id && snapshot.modified == current.modified
            && snapshot.favorite == current.favorite && snapshot.width == current.width
            && snapshot.height == current.height && snapshot.video == current.video
            && snapshot.screenshot == current.screenshot && snapshot.duration == current.duration
    }

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
enum LibraryChangePolicy {
    /// Accept only expected removals, never newly inserted or edited surviving items.
    static func isExpectedDeletion(before: [PhotoItem], after: [PhotoItem], expectedIDs: Set<String>) -> Bool {
        let previous = Dictionary(uniqueKeysWithValues: before.map { ($0.id, $0) })
        let remaining = Set(after.map(\.id))
        guard Set(previous.keys).subtracting(remaining).isSubset(of: expectedIDs) else { return false }
        return after.allSatisfy { current in
            guard let original = previous[current.id] else { return false }
            return SelectionPolicy.unchanged(original, current: current)
                && original.canDelete == current.canDelete
        }
    }
}

enum VideoPolicy {
    static func sorted(_ items: [PhotoItem]) -> [PhotoItem] {
        items.sorted {
            if $0.bytes != $1.bytes { return ($0.bytes ?? -1) > ($1.bytes ?? -1) }
            return $0.id < $1.id
        }
    }
}


