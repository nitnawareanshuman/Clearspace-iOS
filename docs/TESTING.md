# Acceptance tests

Use disposable media/contacts. Record device, OS, library size, timing and failures. Unchecked steps are not claimed as passed.

## Build

- [ ] Xcode 16+ simulator build and all 16 XCTest tests pass.
- [ ] Navigator folders match disk and have no red references.
- [ ] Regenerating the project produces no diff.

## Permissions/lifecycle

- [ ] No permission prompt until its button is tapped.
- [ ] Photos full/limited/denied/restricted; manage selection; revoke or change access in Settings and return.
- [ ] Contacts full/denied/restricted; iOS 18+ limited access and changing shared contacts in Settings; iOS 17 still works.
- [ ] Either category works when the other permission is denied.
- [ ] Cancel or background a scan, then restart; no stale progress/results.

## Photos/screenshots

- [ ] Identical pair, near-identical burst and unrelated photos group sensibly; favorites are recommended keeps.
- [ ] Select suggestions excludes favorites. Cannot select every photo in a group, but can change the keeper.
- [ ] Screenshots support Select all/Clear and full preview.
- [ ] Hidden media excluded; unavailable cloud-only media disclosed.

## Videos

- [ ] Local videos of different sizes/durations ordered largest first; unknown last.
- [ ] Preview plays, pauses, scrubs and stops on dismissal, including from final review.
- [ ] Cloud-only playback gives an error without downloading.
- [ ] Select non-favorites excludes favorites; manual favorite selection is disclosed in review.
- [ ] Large/edited videos do not freeze UI or inflate memory; timed-out sizes are unknown. Measure scan duration.

## Contacts

- [ ] Shared full names, formatted phone numbers and case-varied emails group; blank cards, short extensions and first-name-only matches do not.
- [ ] Overlapping matches, linked cards and different providers display individual records correctly.
- [ ] No auto-selection; prevent selecting every record in a group. Review shows removed and kept cards.
- [ ] Phones/emails/company/job/address/URL/birthday readable; warning explains whole-card deletion including hidden fields.
- [ ] Cancel both stages: no changes. Confirm disposable copies: kept contacts unchanged.
- [ ] Test read-only accounts and revoked access: report errors, rescan, no false success.
- [ ] Edit/delete contact externally during review: stale review blocked.

## Deletion

- [ ] Media review shows exact items, known/unknown totals and favorites warning.
- [ ] Cancel app or iOS Photos confirmation: nothing deleted.
- [ ] Confirm both: selected media enters Recently Deleted; kept media remains; rescan works.
- [ ] External photo changes invalidate review. Actual storage measured separately; no immediate-recovery promise.

## UI/device submission

- [ ] Pip visible in welcome/dashboard/scans/playback loading; Reduce Motion stops floating.
- [ ] Light/dark, largest Dynamic Type, VoiceOver, compact iPhone, landscape and long names usable.
- [ ] Empty, denied, unavailable, stale and error states have a next action.
- [ ] Complete on a real iPhone and record a 2–3 minute walkthrough without private content.


## Deletion continuity and mascot regression

- Scan, delete one similar photo, and approve the iOS prompt. The remaining group stays visible, selection clears, and dashboard counts/estimates update without another scan.
- Delete the recommended keeper while leaving other copies. A surviving photo becomes the keeper; deleting the last copy remains blocked.
- Delete the last extra photo in a group. Show the empty category state, not Scan needed. Check screenshots and videos similarly, including an empty category.
- Cancel the app confirmation and, separately, the iOS prompt. Photos, estimates and results must remain unchanged.
- Repeat deletions to exercise Photos callbacks arriving before/after completion. Own removals must not invalidate the scan. An unrelated insertion, edit or deletion must still invalidate it, including during the confirmation prompt.
- Scan, cancel, scan again; navigate away/back and scroll. The header mascot stays still. Only the scan-card mascot moves subtly inside its frame while scanning. Verify Reduce Motion and background/foreground transitions.

Local validation for this fix: Swift syntax parser, Xcode references, project resources, deletion-site checks and diff whitespace passed. Added four reconciliation XCTest cases. Apple SDK build, XCTest execution, and visual/device verification require Xcode or CI and were not run in the Linux workspace.
