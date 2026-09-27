import SwiftUI
import EventKit

@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var authorization = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var items: [CalendarItem] = []
    @Published private(set) var scanning = false
    @Published private(set) var deleting = false
    @Published private(set) var scanned = false
    @Published private(set) var revision = 0
    @Published var error: String?
    private let service = CalendarService()
    private var observer: NSObjectProtocol?
    var hasAccess: Bool { authorization == .fullAccess }
    var busy: Bool { scanning || deleting }

    init() {
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged,
            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.invalidate() }
        }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    private func invalidate() { revision += 1; items = []; scanned = false }
    func refreshAccess() {
        let current = EKEventStore.authorizationStatus(for: .event)
        if authorization != current { authorization = current; invalidate() }
    }
    func requestAccess() async {
        do { _ = try await service.requestAccess(); refreshAccess(); if hasAccess { await scan() } }
        catch { self.error = error.localizedDescription }
    }
    func scan() async {
        refreshAccess()
        guard hasAccess, !busy else { return }
        invalidate(); scanning = true; error = nil
        let generation = revision
        defer { scanning = false }
        do {
            let found = try await service.scan()
            guard generation == revision, hasAccess else { return }
            items = found; scanned = true
        } catch { self.error = error.localizedDescription }
    }
    func delete(_ reviewed: [CalendarItem], revision expected: Int) async throws -> CleanupReceipt {
        refreshAccess()
        guard hasAccess, !busy, expected == revision, !reviewed.isEmpty,
              reviewed.allSatisfy({ items.contains($0) }) else { throw CalendarCleanupError.stale }
        deleting = true
        defer { deleting = false }
        do {
            try await service.delete(reviewed)
            let receipt = CleanupHistory.shared.record(events: reviewed.count)
            invalidate()
            return receipt
        } catch { invalidate(); throw error }
    }
    #if DEBUG
    func addTestEvents() async {
        guard hasAccess, !busy else { return }
        scanning = true
        do { try await service.addTestEvents() }
        catch { self.error = error.localizedDescription }
        scanning = false
        invalidate()
    }
    #endif

}
