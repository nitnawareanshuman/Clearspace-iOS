//
//  CleanerStore.swift
//  Clearspace
//
//  Created by Anshuman Nitnaware on 02/10/26.
//


import SwiftUI
import Photos
import WidgetKit

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
    @Published private(set) var lastReceipt: CleanupReceipt?
    @Published var message: String?
    @Published var storageError: String?
    private let scanner = LibraryScanner()
    private var storageTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var libraryChangedDuringDelete = false
    private var observedAssets: PHFetchResult<PHAsset>?
    private var expectedDeletedIDs = Set<String>()
    private var observing = false
    var hasAccess: Bool { authorization == .authorized || authorization == .limited }
    var busy: Bool { scanning || deleting }

    override init() {
        super.init()
        updateObservation()
        refreshStorage()
    }
    deinit { if observing { PHPhotoLibrary.shared().unregisterChangeObserver(self) } }

    private func updateObservation() {
        if hasAccess && !observing {
            observedAssets = PHAsset.fetchAssets(with: nil)
            PHPhotoLibrary.shared().register(self)
            observing = true
        } else if !hasAccess && observing {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
            observing = false
            observedAssets = nil
            expectedDeletedIDs.removeAll()
        }
    }

    func refreshStorage() {
        guard storageTask == nil else { return }
        storageTask = Task { [weak self] in
            let snapshot = await Task.detached(priority: .utility) {
                Result { try StorageSnapshot.read() }
            }.value
            guard let self else { return }
            switch snapshot {
            case .success(let value): storage = value; storageError = nil
            case .failure(let error): storage = nil; storageError = error.localizedDescription
            }
            storageTask = nil
            WidgetCenter.shared.reloadTimelines(ofKind: "ClearspaceStorageWidget")
        }
    }
    func refreshAccess() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status != authorization {
            authorization = status
            invalidate("Photos access changed. Scan the available library again.")
        }
        updateObservation()
        refreshStorage()
    }
    func requestAccess() async {
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        refreshAccess()
        if hasAccess { startScan() }
    }
    func refreshLimitedSelection() {
        refreshAccess()
        // The allowed identifiers can change while authorization remains .limited.
        invalidate("Photos selection updated. Scan again to refresh the available library.")
    }
    func startScan() {
        refreshAccess()
        guard hasAccess, !busy else { return }
        epoch += 1
        observedAssets = PHAsset.fetchAssets(with: nil)
        expectedDeletedIDs.removeAll()
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
                phase = scanned.analysisIncomplete ? "Scan finished with limitations" : "Scan complete"
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
            // Ignore notifications unrelated to the fetched assets (for example album changes).
            guard let observedAssets,
                  let changes = changeInstance.changeDetails(for: observedAssets) else { return }
            self.observedAssets = changes.fetchResultAfterChanges
            let removed = Set(changes.removedObjects.map(\.localIdentifier))
            var onlyExpectedDeletion = changes.hasIncrementalChanges
                && changes.insertedObjects.isEmpty && changes.changedObjects.isEmpty
                && removed.isSubset(of: expectedDeletedIDs)
            // Photos can send a nonincremental notification for our own deletion.
            // Verify the before/after snapshots instead of discarding valid results.
            if !onlyExpectedDeletion && (deleting || !expectedDeletedIDs.isEmpty || !changes.hasIncrementalChanges) {
                let before = (0..<observedAssets.count).map { PhotoItem(asset: observedAssets.object(at: $0)) }
                let after = (0..<changes.fetchResultAfterChanges.count).map {
                    PhotoItem(asset: changes.fetchResultAfterChanges.object(at: $0))
                }
                onlyExpectedDeletion = LibraryChangePolicy.isExpectedDeletion(
                    before: before, after: after, expectedIDs: expectedDeletedIDs)
            }
            expectedDeletedIDs.subtract(removed)
            guard !onlyExpectedDeletion else { return }
            if deleting { libraryChangedDuringDelete = true }
            else { invalidate("Your photo library changed. Scan again for up-to-date results.") }
        }
    }
    func makeDraft(_ items: [PhotoItem]) -> ReviewDraft {
        let selected = SelectionPolicy.unique(items)
        let ids = Set(selected.map(\.id))
        let affected = result?.groups.filter { $0.items.contains { ids.contains($0.id) } } ?? []
        return ReviewDraft(epoch: epoch, items: selected,
            kept: SelectionPolicy.unique(affected.flatMap(\.items).filter { !ids.contains($0.id) }))
    }
    func delete(_ draft: ReviewDraft) async throws {
        refreshAccess()
        guard !busy, hasAccess else { throw CleanerError.noAccess }
        guard draft.epoch == epoch, !draft.items.isEmpty, let result else { throw CleanerError.staleReview }
        let ids = Set(draft.items.map(\.id))
        guard Set(makeDraft(draft.items).kept.map(\.id)) == Set(draft.kept.map(\.id)) else {
            throw CleanerError.staleReview
        }
        let knownIDs = Set((result.groups.flatMap(\.items) + result.screenshots + result.videos + result.blurryPhotos).map(\.id))
        guard ids.isSubset(of: knownIDs), SelectionPolicy.allows(ids, groups: result.groups) else {
            throw CleanerError.staleReview
        }
        // Re-fetch survivors too: a delayed change notification must not let the last copy go.
        let expected = SelectionPolicy.unique(draft.items + draft.kept)
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: expected.map(\.id), options: nil)
        guard fetched.count == expected.count else { throw CleanerError.staleReview }
        let snapshots = Dictionary(uniqueKeysWithValues: expected.map { ($0.id, $0) })
        var assets: [PHAsset] = []
        for index in 0..<fetched.count {
            let asset = fetched.object(at: index)
            let current = PhotoItem(asset: asset)
            guard let item = snapshots[asset.localIdentifier],
                  SelectionPolicy.unchanged(item, current: current) else { throw CleanerError.staleReview }
            if ids.contains(asset.localIdentifier) {
                guard current.canDelete else { throw CleanerError.staleReview }
                assets.append(asset)
            }
        }
        deleting = true
        libraryChangedDuringDelete = false
        expectedDeletedIDs.formUnion(ids)
        do {
            // The only mutation site. Called exclusively from the destructive review confirmation.
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
            let sizes = ByteSummary(draft.items)
            lastReceipt = CleanupHistory.shared.record(
                photos: draft.items.filter { !$0.video }.count,
                videos: draft.items.filter(\.video).count,
                bytes: sizes.known, unknownSizes: sizes.unknown)
            if libraryChangedDuringDelete || !hasAccess || self.result == nil {
                invalidate("Your photo library changed during deletion. Scan again for up-to-date results.")
            } else {
                // Preserve the scan and invalidate old review selections, not the whole result.
                self.result = result.removing(ids)
                epoch += 1
                phase = "Library updated after deletion"
            }
            // Rebase observation before leaving the mutation. Delayed notifications
            // are compared with the post-delete library, not an obsolete fetch.
            observedAssets = hasAccess ? PHAsset.fetchAssets(with: nil) : nil
            expectedDeletedIDs.removeAll()
            deleting = false
            refreshStorage()
        } catch {
            expectedDeletedIDs.subtract(ids)
            deleting = false
            if libraryChangedDuringDelete { invalidate("Your photo library changed. Please scan again.") }
            throw error
        }
    }
}
