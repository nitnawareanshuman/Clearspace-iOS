# Validation on your Mac and iPhone

## First build

Open `Clearspace.xcodeproj`, select the Clearspace scheme and an installed iPhone simulator, then use Product → Build (⌘B) and Product → Test (⌘U). For command-line builds:

```bash
xcodebuild -project Clearspace.xcodeproj -scheme Clearspace -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcrun simctl list devices available
# Replace the destination below with one actually installed on your Mac.
xcodebuild -project Clearspace.xcodeproj -scheme Clearspace -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID' CODE_SIGNING_ALLOWED=NO test
```

A GitHub Actions workflow runs the simulator build and rule tests on a macOS runner. It cannot replace physical-device tests.

## Safe fixture set

Use only disposable, non-private photos. Before deleting anything, confirm you have a copy outside the test library.

- 3 duplicated copies of one photo.
- 3 near-identical photos taken within a minute, including one favorite.
- 2 visually different photos taken close together (negative pair).
- 2 same-scene photos with materially different people/expressions (false-positive check).
- A higher-resolution and a lower-resolution variant.
- 5 screenshots, including one favorite.
- A Live Photo and an edited photo.
- At least one cloud-only original where available.

You can drag non-private images into Simulator Photos to exercise the UI. Screenshot detection requires assets with the screenshot subtype; import provenance may not preserve it. Verify screenshots on a physical iPhone. Do not use a fake screenshot flag in release code.

## Required manual checks

| Case | Expected result |
|---|---|
| Fresh install | In-app reason appears before system Photos prompt |
| Deny access | Useful explanation and Settings action; storage dashboard still works |
| Restricted access | Restriction message, no repeated request loop |
| Limited access | Only allowed photos; visible limited banner and manage control |
| Modify limited selection | Previous scan/review invalidated; next scan reflects access |
| Empty library / no matches | Clear empty state, no deletion action |
| Matching/near photos | Groups contain plausible candidates; inspect false positives and misses |
| Favorite with lower resolution | Favorite recommended over larger non-favorite |
| Select suggestions | Keeper and all favorites remain unselected |
| Manually choose another keeper | Allowed if at least one group member stays unselected |
| Select last unselected group member | Prevented with explanation |
| Screenshots select all / clear | Counts correct; final review exactly matches selection |
| Favorite selected manually | Review warns that favorites are included |
| Cloud-only / load timeout | Unknown size or unavailable preview; scan stays responsive; no downloads |
| Cancel scan / background app | Scan ends safely; no incomplete success result |
| Edit/delete photo externally during scan or review | Stale result/review rejected; rescan required |
| Cancel app confirmation | No Photos transaction and no deletion |
| Cancel native Photos dialog | Error/cancellation shown, no false success, items remain |
| Approve deletion on disposable fixtures | Only reviewed IDs removed; keeper survives; categories invalidated |
| Recently Deleted | App explains delayed space reclamation; no inflated "freed" claim |
| iCloud Photos enabled | Confirm warning is visible before approving deletion |
| Light/dark, landscape, small iPhone, largest text | No clipped primary actions; views scroll |
| VoiceOver | Selection state, favorite status, preview action, buttons understandable |

## Performance and accuracy record

Run on 1k then 10k+ accessible photos if available. Record device, iOS, total items, locally analyzed items, unavailable count, candidate count, scan duration, sizing duration if profiled, and peak memory using Xcode Instruments. A result is not a performance pass without measurements.

For accuracy, hand-label at least 30 candidate pairs/groups and negative pairs. Report false positives and misses. Adjust the revision-2 threshold only with evidence; keep the three-signal gate and final review. Recheck edge cases after changing it.

## Submission gate

Do not call the build shippable until the Xcode build, XCTest, and real-device core loop pass. Complete videos and duplicate contacts before claiming the full brief. Record a 2–3 minute walkthrough on a real iPhone using non-private photos. Update `PROGRESS.md` and write the final <150-word note based on actual results.
