# Project progress

Last updated: 2026-09-24 UTC
Current milestone: **M1 — first three features implemented in source; Apple-platform verification pending**.

Status definitions: **Implemented** = source exists; **Verified** = a recorded successful test; **Pending** = not implemented. This distinction matters for the assignment.

## Assignment map

| Brief requirement | Source status | Verification | Main files |
|---|---|---|---|
| 1. Storage dashboard | Implemented for device storage, similar-photo suggestions, screenshots; unbuilt categories labeled | Device totals unverified | `Models/LibraryModels.swift`, `Views/DashboardView.swift` |
| 2. Similar photos | Implemented; conservative suggestions, recommended keep, manual selection | Accuracy and large-library performance unverified | `Services/LibraryScanner.swift`, `Views/PhotoCollectionView.swift` |
| 3. Screenshots | Implemented; screenshot subtype, bulk selection, preview | Real-library scan unverified | `Services/LibraryScanner.swift`, `Views/PhotoCollectionView.swift` |
| 4. Large videos | Pending | Not tested | — |
| 5. Duplicate contacts | Pending | Not tested | — |
| 6. Review before delete | Implemented for M1 photo categories | Real-device deletion/cancellation unverified | `Views/ReviewView.swift`, `App/CleanerStore.swift` |
| 7. Permissions | Photos implemented; Contacts pending with M2 | Denied/limited/revoked device tests pending | `App/CleanerStore.swift`, `Views/DashboardView.swift` |
| Bonus features | Deferred until full core loop works | Not tested | — |

All source paths in the table are under `Clearspace/`.

## M1 checklist

- [x] iOS 17+ SwiftUI app and Xcode project; shared build/test scheme.
- [x] Real device total/used/free values and unknown/error states.
- [x] Photo scan actor, bounded near-match comparisons, no full-image accumulation.
- [x] Global normalized-preview match lookup, Vision revision 2 + perceptual-hash near-match gate.
- [x] Recommended keep based on favorite, resolution, recency; preserve at least one group member.
- [x] Screenshots separated from similar photos to avoid cross-category double counts.
- [x] Empty selection by default; suggestions require a user tap and skip favorites.
- [x] Chunked resource sizing; timeout/cancellation; unknown-size disclosures.
- [x] Full/limited/denied/restricted Photos paths, explicit rationale, limited picker.
- [x] Review previews, favorite warning, final approval and PhotoKit confirmation.
- [x] Refetch and validate deletion IDs, editability, epoch and modification timestamps.
- [x] Recently Deleted and iCloud-deletion implications explained.
- [x] Original logo/design; semantic colors and accessibility labels.
- [x] No login, payment, analytics SDK, upload, or cloud download code.
- [x] Privacy manifest for displaying disk-space values.
- [x] Unit-test source for critical selection and accounting rules.
- [ ] Successful Xcode build and XCTest run.
- [ ] Real-iPhone permission and end-to-end deletion tests.
- [ ] Similarity threshold calibrated against a labeled photo set.
- [ ] Large-library time and peak-memory measurements.
- [ ] Small-screen, landscape, Dynamic Type, VoiceOver and dark-mode QA.

## Verification evidence

See `docs/VALIDATION.md` for checks run in the implementation environment. The environment is Linux and has no Xcode, iOS SDK, or iPhone. Source parsing and project-file checks cannot establish that an iOS app builds or works on a device.

Record actual results here after testing:

| Date | Device / iOS / Xcode | Test | Result / evidence |
|---|---|---|---|
| — | — | Xcode build and unit tests | Pending |
| — | — | Scan → review → cancel/delete | Pending |
| — | — | Limited access / denied / changes | Pending |
| — | — | 1k / 10k+ photo library speed, peak memory | Pending |

## Next work, in order

1. **M1 validation:** open in Xcode, fix any build errors, run the test matrix, and calibrate similarity. Record exact errors/results here.
2. **M2 large videos:** asynchronous video resource sizing, descending sort, local playback, selection, existing review safety, unknown cloud-size states.
3. **M3 duplicate contacts:** contextual Contacts permission, normalized phone/email matching, field-preserving merge review, and safe deletion. Do not auto-merge ambiguous names.
4. **M4 submission polish:** full regression on a real iPhone, honest missing-feature list, 2–3 minute recording with no private photos, <150-word submission note, optional TestFlight.

## Repository publishing

The initial project was prepared locally. Remote creation requires the account's GitHub sign-in; do not consider a remote created until a verified URL is recorded here.

## Working agreement

For each change: update this file, explain why, list affected files, record tests actually run, and preserve known limitations. Do not claim all seven requirements are complete after M1. Do not add a compiler, backend, payments, or unrelated features.
