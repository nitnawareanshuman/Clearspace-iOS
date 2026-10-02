import Foundation

/// A short review session, not a claim that a screenshot is safe to remove.
enum TidySessionPolicy {
    static let batchLimit = 10

    static func candidates(from result: ScanResult, excluding reviewed: Set<String> = []) -> [PhotoItem] {
        let eligible = SelectionPolicy.unique(result.screenshots).filter {
            $0.screenshot && !$0.video && $0.canDelete && !$0.favorite && !reviewed.contains($0.id)
        }
        let oldestFirst = eligible.sorted { left, right in
            switch (left.created, right.created) {
            case let (a?, b?) where a != b: return a < b
            case (_?, nil): return true
            case (nil, _?): return false
            default: return left.id < right.id
            }
        }
        return Array(oldestFirst.prefix(batchLimit))
    }
}
