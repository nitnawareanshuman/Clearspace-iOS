import SwiftUI
import Contacts

@MainActor
final class ContactsStore: ObservableObject {
    @Published private(set) var authorization = CNContactStore.authorizationStatus(for: .contacts)
    @Published private(set) var groups: [ContactGroup] = []
    @Published private(set) var scanned = false
    @Published private(set) var scanning = false
    @Published private(set) var deleting = false
    @Published private(set) var epoch = 0
    @Published var message: String?
    private let service = ContactService()
    private var task: Task<Void, Never>?
    private var observer: NSObjectProtocol?
    var busy: Bool { scanning || deleting }
    var hasAccess: Bool { ContactService.hasAccess }
    var limited: Bool {
        if #available(iOS 18.0, *) { return authorization == .limited }
        return false
    }
    var duplicateCount: Int { groups.reduce(0) { $0 + max(0, $1.records.count - 1) } }

    init() {
        observer = NotificationCenter.default.addObserver(forName: .CNContactStoreDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                invalidate()
            }
        }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    func refreshAccess() {
        let current = CNContactStore.authorizationStatus(for: .contacts)
        if current != authorization { authorization = current; invalidate() }
        else if limited && !busy && scanned {
            // Returning from Settings can change allowed IDs without changing the status.
            invalidate()
        }
    }
    func requestAccess() async {
        do {
            _ = try await service.requestAccess()
            refreshAccess()
            if hasAccess { startScan() }
        } catch { message = error.localizedDescription }
    }
    func startScan() {
        guard hasAccess, !busy else { return }
        invalidate()
        let generation = epoch
        scanning = true
        task = Task {
            do {
                let found = try await service.scan()
                try Task.checkCancellation()
                guard generation == epoch else { return }
                groups = found; scanned = true
            } catch is CancellationError { }
            catch { if generation == epoch { message = error.localizedDescription } }
            if generation == epoch { scanning = false; task = nil }
        }
    }
    func cancelScan() { if scanning { invalidate() } }
    private func invalidate() {
        task?.cancel(); task = nil; epoch += 1
        scanning = false; groups = []; scanned = false
    }
    func makeDraft(_ ids: Set<String>) -> ContactDraft? {
        guard !busy, hasAccess, ContactPolicy.allows(ids, groups: groups.map { $0.records.map(\.id) }) else { return nil }
        let affected = groups.filter { $0.records.contains { ids.contains($0.id) } }.flatMap(\.records)
        return ContactDraft(epoch: epoch, records: affected.filter { ids.contains($0.id) }, kept: affected.filter { !ids.contains($0.id) })
    }
    func delete(_ draft: ContactDraft) async throws {
        guard !busy, hasAccess, draft.epoch == epoch,
              let current = makeDraft(Set(draft.records.map(\.id))),
              Set(current.kept.map(\.id)) == Set(draft.kept.map(\.id)) else { throw ContactError.stale }
        deleting = true
        do {
            try await service.delete(draft)
            deleting = false; invalidate()
            message = "Deleted \(draft.records.count) contacts. Scan again to refresh your results."
        } catch {
            deleting = false; invalidate()
            // Re-scan even on error: a provider might reject a write or change access.
            throw error
        }
    }
}
