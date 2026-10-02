# PipSweep validation record

Prepared 2 October 2026 from main commit `3cedd7e2bacd4fbc0f2f5299fc7fde03bb719578`. The release scope is the standalone product described in [FEATURES.md](FEATURES.md).

## Changes prepared

| Area | Change |
| --- | --- |
| Identity | PipSweep display names, permission explanations, widget labels and welcome; internal module, bundle IDs, widget kind and history key retained. |
| Mascot | Pip holds a drawn broom; decorative motion respects Reduce Motion. Matching opaque App Store icon added. |
| Product workflow | Up to ten eligible screenshots per batch, oldest first; favorites skipped. Reuses swipe review, previews, Undo, group protection and the existing final deletion review. |
| Help and privacy | Settings, offline policy, permission shortcut, recovery guidance and clear-history control. Public support contact is configurable and must be filled before submission. |
| Image analysis | Overlapping regional edge checks protect small sharp subjects at grid boundaries; global variance remains calculated once per pixel. |
| Release configuration | App and widget version/build aligned to 1.0.0 (2). CI guards the submission SDK and adds an unsigned Release device build. |
| Submission materials | Support/privacy page templates, App Store copy, reviewer notes, signing guidance and device acceptance checklist. |

## Checks passed in this workspace

- Grammar parsing of all **35 Swift files** using tree-sitter-swift. This does not check Swift types or Apple API compatibility.
- OpenStep parsing of **129 Xcode project objects**, reference consistency, source-path resolution and target membership. All Swift files are accounted for; new app/test files are registered in the intended targets.
- Parsing of **7 XML configuration files**, including Info.plist, privacy manifests, schemes and workspace data; asset JSON parsing.
- App/widget display names, matching 1.0.0 (2) versions and iOS 17 deployment settings.
- Workflow YAML, the iOS 26-or-newer SDK guard, simulator build, Release iPhone build and XCTest step presence. The updated workflow has not been executed.
- Both icon copies are valid **1024 × 1024 RGB PNGs** with no alpha channel.
- Public page relative links and matching offline/web privacy text. Private-repository support links were removed. The actual support contact and public hosting remain unconfigured.
- `git diff --check`.

## Numerical blur regression evidence

Integer luminance fixtures were evaluated independently with Python/NumPy using the same regional equations. These checks do not execute the Swift implementation or Core Image.

| Fixture | Global variance | Sharpest region | Result |
| --- | ---: | ---: | --- |
| Sharp checkerboard, updated algorithm | 9534.75 | 10153.13 | Not blurry |
| Small sharp subject, previous 4 × 4 grid | 34.01 | 520.98 | Incorrectly blurry |
| Same subject, updated overlapping grids | 34.01 | 2080.94 | Protected |
| Subject at a boundary, non-overlapping 8 × 8 grid | 32.09 | 500.49 | Incorrectly blurry |
| Same boundary subject, updated overlapping grids | 32.09 | 1959.45 | Protected |
| SciPy Gaussian approximation, updated algorithm | 12.09 | 12.72 | Blurry |

The Gaussian approximation is not evidence that Core Image produces identical pixels. Run the native Gaussian XCTest on a Mac.

## Native build and tests still required

The prior main [GitHub Actions run](https://github.com/nitnawareanshuman/Clearspace-iOS/actions/runs/36455302621) built with Xcode 16.4 and reported **57 of 58 tests passing**. `testSharpSubjectAgainstSoftBackgroundIsProtected` failed; its classification is addressed by the regional change above. That earlier run does not validate this update.

There are now **65 XCTest methods in source**, including new coverage for regional boundary subjects, session eligibility/order and history clearing. **They were not executed in this workspace.** Xcode, the Apple SDKs, a simulator and a real iPhone are unavailable here. Do not infer a compiled or passing app from grammar parsing or numerical checks.

Run Xcode tests and a Release build, then complete [TESTING.md](TESTING.md) with disposable content. Verify new-screen layouts, broom clipping, VoiceOver, Dynamic Type, permissions, cancellation, last-copy protection, actual deletion and widget behavior. Capture [SCREENSHOTS.md](SCREENSHOTS.md), configure the public support contact, publish the policy/support pages, validate a signed archive and test through TestFlight before submission.

Name availability must be confirmed in App Store Connect. This update does not establish App Store approval.
