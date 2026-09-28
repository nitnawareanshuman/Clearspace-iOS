import SwiftUI

struct CleanupReceipt: Identifiable, Codable, Equatable {
    var id = UUID()
    var date = Date()
    var photos = 0
    var videos = 0
    var contacts = 0
    var events = 0
    var estimatedBytes: Int64 = 0
    var unknownSizes = 0
    var itemCount: Int { photos + videos + contacts + events }
}

@MainActor
final class CleanupHistory: ObservableObject {
    static let shared = CleanupHistory()
    @Published private(set) var receipts: [CleanupReceipt]
    private let defaults: UserDefaults
    private let key = "clearspace.cleanupHistory.v1"
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        receipts = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([CleanupReceipt].self, from: $0) } ?? []
    }
    @discardableResult
    func record(photos: Int = 0, videos: Int = 0, contacts: Int = 0, events: Int = 0,
                bytes: Int64 = 0, unknownSizes: Int = 0) -> CleanupReceipt {
        let receipt = CleanupReceipt(photos: photos, videos: videos, contacts: contacts, events: events,
                                     estimatedBytes: max(0, bytes), unknownSizes: unknownSizes)
        guard receipt.itemCount > 0 else { return receipt }
        receipts.insert(receipt, at: 0)
        if let data = try? JSONEncoder().encode(receipts) { defaults.set(data, forKey: key) }
        return receipt
    }
}
