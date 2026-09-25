import SwiftUI
import Photos

@MainActor
final class CleanerStore: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published private(set) var authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published private(set) var result: ScanResult?
    @Published private(set) var storage: StorageSnapshot?
    @Published private(set) var scanning = false
    @Published private(set) var deleting = false
    @Published private(set) var progress = 0.0
    @Published private(set) var phase = "Ready to scan"
    @Published private(set) var epoch = 0
    @Published var message: String?
    @Published var storageError: String?
    private let scanner = LibraryScanner()
    private var scanTask: Task<Void, Never>?
    private var libraryChangedDuringDelete = false
    var hasAccess: Bool { authorization == .authorized || authorization == .limited }
    var busy: Bool { scanning || deleting }

    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
        refreshStorage()
    }
    deinit { PHPhotoLibrary.shared().unregisterChangeObserver(self) }

    func refreshStorage() {
        do { storage = try StorageSnapshot.read(); storageError = nil }
        catch { storage = nil; storageError = error.localizedDescription }
    }
    func refreshAccess() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status != authorization {
            authorization = status
            invalidate("Photos access changed. Scan the available library again.")
        }
        refreshStorage()
    }
    func requestAccess() async {
        authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        if hasAccess { startScan() }
    }
    func startScan() {
        guard hasAccess, !busy else { return }
        epoch += 1
        let generation = epoch
        result = nil
        scanning = true
        progress = 0
        phase = "Preparing your library"
        message = nil
        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                let scanned = try await scanner.scan { [weak self] label, fraction in
                    await self?.updateProgress(label, fraction: fraction, generation: generation)
                }
                try Task.checkCancellation()
                guard epoch == generation else { return }
                result = scanned
                phase = "Scan complete"
                progress = 1
            } catch is CancellationError {
                if epoch == generation { phase = "Scan cancelled" }
            } catch {
                if epoch == generation { message = error.localizedDescription }
            }
            if epoch == generation { scanning = false; scanTask = nil; refreshStorage() }
        }
    }
    private func updateProgress(_ label: String, fraction: Double, generation: Int) {
        guard generation == epoch else { return }
        phase = label
        progress = fraction
    }
    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        epoch += 1
        scanning = false
        phase = "Scan cancelled. Start again when you are ready."
    }
    private func invalidate(_ reason: String) {
        cancelScan()
        result = nil
        phase = reason
    }
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if deleting { libraryChangedDuringDelete = true }
            else { invalidate("Your photo library changed. Scan again for up-to-date results.") }
        }
    }
    func makeDraft(_ items: [PhotoItem]) -> ReviewDraft {
        ReviewDraft(epoch: epoch, items: SelectionPolicy.unique(items))
    }
    func delete(_ draft: ReviewDraft) async throws {
        guard !busy, hasAccess else { throw CleanerError.noAccess }
        guard draft.epoch == epoch, !draft.items.isEmpty, let result else { throw CleanerError.staleReview }
        let ids = Set(draft.items.map(\.id))
        let knownIDs = Set((result.groups.flatMap(\.items) + result.screenshots + result.videos).map(\.id))
        guard ids.isSubset(of: knownIDs), SelectionPolicy.allows(ids, groups: result.groups) else {
            throw CleanerError.staleReview
        }
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: Array(ids), options: nil)
        guard fetched.count == ids.count else { throw CleanerError.staleReview }
        let snapshots = Dictionary(uniqueKeysWithValues: draft.items.map { ($0.id, $0) })
        var assets: [PHAsset] = []
        for index in 0..<fetched.count {
            let asset = fetched.object(at: index)
            guard asset.canPerform(.delete), let item = snapshots[asset.localIdentifier],
                  asset.modificationDate == item.modified else { throw CleanerError.staleReview }
            assets.append(asset)
        }
        deleting = true
        libraryChangedDuringDelete = false
        do {
            // The only mutation site. Called exclusively from the destructive review confirmation.
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
            deleting = false
            invalidate("Deletion approved. Scan again to refresh categories.")
            refreshStorage()
            message = "Removed \(ids.count) items from your library. Photos keeps them in Recently Deleted for up to 30 days. Device space may not increase immediately. If iCloud Photos is enabled, deletion also syncs to your other devices."
        } catch {
            deleting = false
            if libraryChangedDuringDelete { invalidate("Your photo library changed. Please scan again.") }
            throw error
        }
    }
}
