# Build and acceptance tests

Use disposable content for destructive tests. An unchecked step is not a passed test. Record the commit, Xcode version, device, iOS version, library size, scan time, and any failures.

## Build and XCTest

Open `Clearspace.xcodeproj`, select the **Clearspace** scheme, and run **Product → Test** on an available iPhone simulator. Both the app and embedded widget target iOS 17+. Xcode 16+ is required by the project's synchronized folders and limited-Contacts API usage.

For command-line testing on a Mac:

```bash
xcodebuild -project Clearspace.xcodeproj -scheme Clearspace \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

xcrun simctl list devices available

# Replace the identifier with an installed iPhone simulator's UDID.
xcodebuild -project Clearspace.xcodeproj -scheme Clearspace \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID' \
  CODE_SIGNING_ALLOWED=NO -resultBundlePath TestResults.xcresult test
```

GitHub Actions builds and tests on pull requests and pushes to `main` or `bonus`. It selects an installed iPhone simulator and uploads its `.xcresult` bundle. Static source parsing is not a substitute for these Apple SDK checks.

## Sample data

- Three copies of a disposable photo, three near-identical shots, and unrelated images.
- A photo with rotation/mirroring metadata and a visibly rotated copy; inspect matching suggestions.
- Duplicated screenshots, favorites, and a cloud-only asset where available.
- Three locally available videos with different sizes, including one favorite.
- Sharp, deliberately blurred, sharp-subject/soft-background, and nearly blank photos.
- Disposable contacts sharing names, formatted numbers, or case-varied emails, plus unrelated cards.
- Old writable calendar events, recent/future events, recurring events, invitations, and a read-only calendar where available.

Simulator media can be dragged into its window. Use Contacts and Calendar to create sample records. A new simulator alone does not exercise large-library behavior or account-provider restrictions.

## Acceptance checklist

### Permissions and lifecycle

- [ ] No prompt before the feature's access button is tapped.
- [ ] Photos: full, limited, denied, restricted; change the limited selection; revoke access in Settings and return.
- [ ] Contacts: full, denied, restricted, and iOS 18+ limited access; change shared contacts and return.
- [ ] Calendar: denied/full access and revocation; other cleanup domains remain usable.
- [ ] Cancel media/contact scans and restart; background during scanning; no stale results or progress.
- [ ] Change media, contacts, or events outside the app while review is open; stale review cannot proceed.

### Media and review

- [ ] Matching previews group; unrelated images remain separate; inspect near-shot and rotated-image suggestions.
- [ ] Favorites, resolution, and recency affect recommended keeps; manual selection can choose another survivor.
- [ ] Individual and bulk selection preserve one photo per matched group, including screenshots/blur overlap.
- [ ] Read-only media is not selected; unavailable media and byte sizes are disclosed.
- [ ] Video order is largest-known-first; unknown sizes are last; preview playback stops when dismissed.
- [ ] Blurry suggestions exclude screenshots; flat/tiny images are unassessable; intentional soft focus is reviewed manually.
- [ ] Swipe left/right, Keep/Remove buttons, rapid taps, Undo, grid return, and interrupted animations preserve the selection.
- [ ] Final review shows exact removed/kept items, favorites warning, and known/unknown byte totals.
- [ ] Cancel the app confirmation and, separately, the Photos prompt; nothing changes and no receipt is added.
- [ ] Confirm a sample deletion; only reviewed media disappears, results/counts update, and retained copies survive.
- [ ] Delete the last extra member of a group: show an empty category while preserving other scan results.
- [ ] Change the library during the system prompt; unrelated changes require a fresh scan.

### Contacts and Calendar

- [ ] Contacts start unselected; shared details form candidate groups, not guaranteed identities.
- [ ] Selecting all cards in a contact group is blocked. Review shows whole-card deletion warnings and retained cards.
- [ ] Cancelling contact confirmation makes no changes. Confirming deletes only disposable selected cards; there is no merge action.
- [ ] Read-only accounts/provider failures show errors and require a rescan without a success receipt.
- [ ] Calendar lists only writable, non-recurring, non-detached, non-invitation events from the past year that ended over 30 days ago.
- [ ] Calendar review shows titles, calendar names, dates, and available notes/location. Cancel leaves events unchanged.
- [ ] External event edits invalidate review. Successful deletion records item counts without invented byte savings.

### Widget, summary, and presentation

- [ ] Build and install the **Clearspace** app with its extension on iOS 17 and a newer supported iOS version.
- [ ] Launch once; find Clearspace in Add Widget; add small and medium widgets; tap to open the app.
- [ ] Only the storage widget is offered; no sample timer or placeholder Live Activity remains.
- [ ] Capacity, unavailable state, timestamp, and dark appearance are readable. Refresh is system-scheduled, not guaranteed every 30 minutes.
- [ ] Summary survives relaunch; cancelled/failed actions add no receipt; restoring Photos does not rewrite history.
- [ ] Inspect compact iPhone, landscape, large Dynamic Type, VoiceOver, light/dark appearance, long names, and Reduce Motion.
- [ ] Test scan time and responsiveness with a real library; simulator storage reports Mac capacity.
- [ ] Capture the [README screenshots](SCREENSHOTS.md) and a separate 2–3 minute real-iPhone walkthrough with no private content.

Do not clear Recently Deleted solely to demonstrate an immediate storage increase.

## Device record

| Field | Result |
| --- | --- |
| Commit and Xcode | Pending |
| iPhone and iOS | Pending |
| Photos / videos / permission state | Pending |
| First scan / repeat scan duration | Pending |
| Build and XCTest | Pending |
| Destructive and cancellation checks | Pending |
| Widget gallery and refresh | Pending |
| Remaining failures | Pending |
