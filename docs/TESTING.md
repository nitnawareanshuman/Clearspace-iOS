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
