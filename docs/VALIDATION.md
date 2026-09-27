# Review and validation record

Reviewed on 28 September 2026 against the supplied AppFactory assignment, starting from `bonus` commit `76ae01cf3fe5e0aada4c7c9995123a2e971d36d8`.

## Corrections in this review

| Finding | Change |
| --- | --- |
| Widget extension required iOS 27 while the app required iOS 17 | Align both widget configurations to iOS 17 and iPhone; enforce extension-safe APIs. |
| Widget bundle registered unfinished timer/control and Live Activity examples | Remove the sample files and registrations; set the debug scheme's widget kind explicitly. |
| Matching read raw CGImage pixels without UIImage orientation | Normalize rotation/mirroring before preview hashes and Vision; add orientation and dimension regression cases. |
| A scan with unknown sizes or skipped blur checks could say complete without limitations | Include those counters in `analysisIncomplete`; extend regression assertions. |
| Review/cache snapshot comparison omitted creation date and deletion capability | Compare both fields; add stale-snapshot tests. |
| Storage usage fraction could exceed its valid range | Clamp the displayed fraction and extend its regression test. |
| Contact rescan could leave an earlier error message visible | Clear the message when a new scan starts. |
| Calendar and history lists eagerly constructed every row | Use lazy vertical stacks. |
| Dashboard source had an accidental ` 2` suffix | Rename it and update all Xcode references. |
| Docs described old scripts, a fixed old test count, and incomplete bonus coverage | Rewrite README and docs; remove obsolete audit/change logs, `PROGRESS.md`, and `scripts/`; update the issue template. |
| Direct pushes to the working branch did not run CI | Include `bonus` alongside `main` in the existing push trigger. |

## Local evidence

Passed in the Linux review workspace:

- Swift grammar parsing for all 31 remaining Swift files, using tree-sitter-swift. This is not Swift compiler type checking.
- OpenStep parsing and consistency checks for Xcode groups, explicit file references, source memberships, and build-object references.
- All Swift files accounted for by explicit or synchronized target membership.
- XML/property-list parsing for schemes, workspace, Info.plist files, and privacy manifests; asset JSON parsing.
- App/widget iOS 17 deployment settings, single widget entry point, and storage-only widget registration.
- Documentation relative-link checks. The unchanged PNG app icon was verified as present in the source Git tree; the text-only connector did not download its bytes.
- Requested removals and absence of stale references; local-only media request settings and a single PhotoKit deletion call site.
- `git diff --check`.

There are 50 XCTest methods in the source after this review. **They were not executed in this workspace.** Xcode, Apple SDKs, an iOS simulator, and a real iPhone are unavailable here. Build and XCTest results must come from the PR's GitHub Actions run or a Mac; do not infer a passing build from parsing.

## Acceptance still required

Follow [TESTING.md](TESTING.md) for permission transitions, cancellation, provider errors, actual deletion, widget discovery, image accuracy, performance, and visual/accessibility checks. Capture the views in [SCREENSHOTS.md](SCREENSHOTS.md). This review does not establish that the entire app is bug-free or ready for TestFlight.
