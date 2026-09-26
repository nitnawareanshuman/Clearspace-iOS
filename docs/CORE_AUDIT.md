# Must-have audit — 26 September 2026

Audited against the supplied AppFactory storage-cleaner brief, starting from main
`f7f44a168eb340715b78b39aea12fe74368a6286`. Source implementation is not a substitute
for real-device acceptance. No real iPhone was available in this execution environment.

| Requirement | Implementation and fixes | Device acceptance |
| --- | --- | --- |
| Storage dashboard | Used/free storage; explicitly labeled potential savings per media category; combined total counts identifiers once. Read-only items and protected keeps excluded. Unknown sizes remain unknown; contacts show counts because reliable byte sizes are unavailable. | Compare empty, known-size, unknown-size and overlapping screenshot/similar results. |
| Similar photos | Preview matching across the library and conservative near-shot matching; favorites/resolution/recency choose a recommended keep. Matching screenshots now participate too. | Duplicate a disposable photo and screenshot; take near-identical shots; check unrelated images do not group. |
| Screenshots | All accessible non-hidden screenshots, previews and multi-selection. Bulk selection now preserves one copy of matching groups and excludes read-only assets. | Select all, clear, select individually, preview and cancel review. |
| Large videos | Descending measured sizes, stable ties, unknown last, local playback. Resource reads now allow 120 seconds instead of the thumbnail's 12-second limit. Successful sizes are reused in memory when modification metadata is unchanged. | Include short/large/edited/cloud-only videos; check order, playback, rescan and cancellation. |
| Duplicate contacts | Shared full name, phone or email candidates. Delete individual cards after review while keeping at least one. Deletion is the permitted alternative to merging. | Create disposable duplicates and shared-name nonduplicates; inspect kept/deleted details, cancel, then confirm. |
| Review before delete | Exact selected media and kept photos shown separately. Both selected photos and survivors are fetched again before deletion; changed dimensions/favorites/modification metadata block stale reviews. Existing contact snapshot checks and explicit confirmations retained. | Cancel at both app and iOS photo prompts. Remove/edit a kept photo outside Clearspace before confirming; require a rescan. |
| Permissions | Separate explanations; denied/restricted/limited states. Photo observation starts only after access. Closing the limited-photo selector invalidates old results even when the status stays limited; limited contacts are refreshed after returning to the app. | Test deny, selected-only, full access, Settings changes, and revocation independently for Photos and Contacts. |

## Regression coverage

Added tests for cross-category byte deduplication, duplicate unknown sizes, bulk keep-one
selection, read-only exclusion, changes to favorites without a modification timestamp,
and PhotoKit requests completing more than once or cancelling before continuation attachment.
Existing keeper, contact matching, unknown-size and video ordering tests remain.

## Known limits to describe honestly

- Matching previews are suggestions, not file-content equality. Near-shot comparisons use
  up to 24 recent group anchors within 60 seconds; near-duplicates outside that window
  may be missed. Screenshots use matching previews only, to avoid grouping distinct text.
- Hidden assets are excluded. Cloud-only resources are not downloaded, so previews,
  grouping or byte sizes can be unavailable. No private file-size API is used.
- Resource bytes estimate library content, not guaranteed immediate free space. Recently
  Deleted, iCloud optimization, shared resources and system accounting affect actual storage.
- The first scan streams resource data and may be slow on large libraries. Scan timing and
  memory use need a real library. The cache is memory-only, and entries without reliable
  modification dates are measured again.
- Contacts are not merged. Names or shared phone/email values can identify different people;
  nothing is selected automatically. Notes and other unshown fields are removed with a card.
- Preflight checks narrow stale-review races but cannot lock Photos against changes by
  another app during the system confirmation. Re-test this flow on the target iOS version.

## Real-iPhone test record

Use disposable content for destructive tests. Do not clear Recently Deleted merely to
demonstrate a storage increase. Keep private media out of the submission recording.

Record: iPhone model ___ / iOS ___ / photos ___ / videos ___ / first scan ___ seconds /
second scan ___ seconds / permission state ___ / commit ___ / observed issues ___.

1. Build the audit branch in Xcode, select your signing team and connected iPhone, then Run.
2. Deny each permission independently; verify the other feature remains usable.
3. Grant limited access and scan; change the allowed selection, then scan again.
4. Verify all four categories using disposable data and compare their review selections.
5. Cancel every review/confirmation route; verify that nothing was removed.
6. Confirm one media deletion and one duplicate-contact deletion; verify only reviewed
   items disappear and retained copies survive. Rescan and check the updated categories.
7. Change a favorite, edit a photo, delete a kept copy, and revoke access while a review
   is open; stale reviews must not proceed with the old selection.
8. Cancel mid-scan, start again, background/foreground, rotate the phone, and try large text.
9. Record the result and a 2–3 minute walkthrough only after these checks pass.
