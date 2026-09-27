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
- Scan, cancel, scan again; navigate away/back and scroll. The header and splash mascot gently breathe and blink. Working and cleanup movement remains inside its frame. Verify Reduce Motion and background/foreground transitions.

Local validation for this fix: Swift syntax parser, Xcode references, project resources, deletion-site checks and diff whitespace passed. Added four reconciliation XCTest cases. Apple SDK build, XCTest execution, and visual/device verification require Xcode or CI and were not run in the Linux workspace.



## Contact merge and cleanup feedback regression

- In a disposable same-account contact group, keep a card with only a phone and merge a duplicate with the same phone plus an email. Preview must show both phone and email; saving must retain the keeper ID and remove only the source card.
- Choose the other keeper; verify the preview changes and the notes acknowledgement resets.
- Cancel merge review or final confirmation: no contact writes. Change a contact/access externally during review: write blocked.
- Different organizations, birthdays or contact photos: merge blocked without silently dropping conflicting values. Contacts from different accounts: service rejects the merge before saving.
- Notes and account-specific fields/group membership are not copied. Copy required notes to the keeper in Contacts, then rescan and review before merging.
- After photo/video deletion, a completion companion appears only on success. Continue returns to remaining items in the same category. The last group/video yields an animated scan-again state with an in-place button.
- Cancel the Photos system prompt or force a write error: no success popup; results remain unless an actual library/access change invalidates them.
- Repeat with nonincremental and delayed Photos notifications; expected removals must not discard remaining results. External inserts, edits and unrelated removals must still invalidate stale analysis.
- Check large Dynamic Type, VoiceOver, Reduce Motion, background/foreground, and repeated presentation of cleanup/review sheets.

Added XCTest coverage for merge field preservation, conflict rejection, keeper choice,
invalid inputs and Photos change classification. Local syntax/project/static checks pass;
Apple SDK compilation, XCTest execution and animation verification require Xcode/CI.
