# Architecture

## Data flow

`DashboardView → CleanerStore → LibraryScanner → PhotoRequests → PhotoKit`

`PhotoCollectionView → immutable ReviewDraft → ReviewView → CleanerStore.delete → PhotoKit.performChanges`

- **SwiftUI views** render state and collect explicit intent. Selections are empty by default and stay in memory.
- **CleanerStore** is MainActor-isolated. It owns access, scan lifecycle, generations, storage values, and the only deletion entry point.
- **LibraryScanner** is an actor. It enumerates accessible non-hidden images, produces compact descriptors, groups suggestions, then measures resources only for screenshots/group members.
- **PhotoRequests** bridges PhotoKit callbacks. A lock-protected one-shot gate handles callback races, cancellation and 12-second per-request timeouts. No request permits network access. Resource chunks are counted and discarded.
- **Value models** store PhotoKit IDs, dates, resolution, favorite status and optional byte sizes; no private photos are saved in the repository or app cache.

## Matching algorithm

1. Enumerate image assets by creation date. Route screenshot subtypes into a separate category.
2. Request a local 256-pixel preview. Generate a Vision revision-2 feature print, a 64-bit difference hash, and a SHA-256 digest of a normalized 128×128 RGBA preview plus original dimensions.
3. A normalized-preview digest match joins its existing group globally. This is visual-preview equality, not an original-resource cryptographic duplicate test. UI says **Matching previews**.
4. Otherwise compare against up to 24 recent group anchors, only within 60 seconds, with aspect difference <0.025, Hamming distance ≤6 and Vision distance ≤0.18.
5. Compare against the original anchor to reduce transitive chains. Keep one ID per digest and only 24 feature-print anchors in memory. Group only buckets with at least two assets.
6. Recommend a favorite first, then the greatest pixel area, then newest date, with stable ID as tie-break. Other favorites are excluded from bulk suggestions. A user may choose another keeper.

The thresholds are initial conservative choices, not empirically validated accuracy claims. Similar re-exports far apart in time with different encodings/dimensions can be missed; repeated compositions can still produce false positives. Face/blur/aesthetic scoring is not implemented. Review is mandatory.

Approximate complexity: metadata/digest storage O(n), descriptor generation O(n), at most 24 near comparisons per non-screenshot photo. Resource I/O is proportional to candidate bytes. Sequential reads bound I/O but may be slow for large candidate sets. No persistent index/cache yet. Measure on device before optimizing further.

## Storage accounting

Device usage comes from Foundation's volume total and available capacity, separately from photo estimates. It can differ from Settings' storage breakdown and purgeable-space accounting.

Candidate size is the sum of available PhotoKit resource data, including edits and Live Photo motion. Partial resource failures make the whole asset's size unknown. Counts do not fabricate estimates for cloud-only originals. No unsupported `value(forKey: "fileSize")` is used.

These are **logical resource bytes**, not exact occupied device blocks or immediate savings. Edits/optimized originals/resource sharing and Recently Deleted affect actual reclamation. The UI reports unknown counts, excludes keeper/favorite suggestions, separates screenshots, and makes no claim to clear other apps' caches.

## Deletion invariants

- The only `deleteAssets` call is in `CleanerStore.delete`.
- The user must explicitly select, open a final review, press Delete, confirm the destructive dialog, and approve PhotoKit's system prompt.
- Review IDs are deduplicated. The immutable draft carries a library epoch.
- Scan changes, permission changes and library notifications invalidate old epochs.
- Immediately before deletion, refetch IDs and verify all remain visible, editable for deletion, in the scanned candidate set, and unmodified since the scan. At least one group member must remain.
- PhotoKit's change transaction handles actual mutation; the app does not locally mark deletion successful before it completes.
- Failure/cancellation preserves the selection unless a concurrent library change requires a new scan. Double submission is blocked while deleting.
- During deletion, notifications are recorded rather than interrupting the system confirmation. On success, clear stale categories and read storage again.
- A tiny external-change race between refetch and the PhotoKit transaction remains subject to PhotoKit's transaction behavior; no app can lock the user's entire Photos library.

## Permissions and lifecycle

Read/write Photos access is requested only after the in-app explanation. Limited access means partial results, displayed prominently. Restricted access has no misleading retry request. Denied access offers Settings. Contacts permission is intentionally absent until the Contacts feature exists.

PhotoKit library notifications invalidate results conservatively. The foreground transition rereads permission and storage. Backgrounding cancels an active scan; the UI asks the user to keep the app open. Scans can be restarted; no partial result is presented as complete.

## Extending the app

Add video models and an AVKit preview in M2, keeping unknown resource sizes explicit. Reuse the review/epoch strategy but update candidate validation deliberately. Contacts need a separate store and immutable review model; do not pass contact IDs through PhotoKit models. Never reuse the visual-photo heuristic to merge contacts.
