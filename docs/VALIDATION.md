# Validation evidence — 2026-09-24 UTC

The implementation environment is Linux, without Swift, Xcode, the iOS SDK, a simulator, or an attached iPhone.

## Checks actually run

- **PASS:** Tree-sitter Swift syntax parsing of all 10 Swift files (9 app sources and 1 test source); zero parse errors after fixing the preview-view closing brace.
- **PASS:** OpenStep parsing of the checked-in Xcode project: 51 objects; every Swift file is referenced and every referenced source/resource exists.
- **PASS:** Property-list parsing of Info.plist and PrivacyInfo.xcprivacy.
- **PASS:** Asset JSON, scheme XML, and CI YAML parsing.
- **PASS:** Shell syntax check of `scripts/create_github_repo.sh`.
- **PASS:** Static inspection confirms one PhotoKit deletion call, no enabled network downloads, no URLSession client, and no private file-size KVC lookup.

The included `scripts/validate_source.py` can reproduce the syntax/structure checks after installing the optional Python parser dependencies listed in its docstring. These are developer tools only; the iPhone app has no external dependencies.

## Not run

- Swift compiler / Apple SDK type-check and linking.
- Xcode build, simulator launch, XCTest execution, CI execution.
- Runtime permission handling, real deletion/cancellation, stale-review integration behavior.
- Similarity accuracy and threshold calibration, large-library runtime or memory measurement.
- Visual, accessibility, signing, provisioning, archive or TestFlight verification.

Nine XCTest methods are supplied for selection/keeper rules, deduplication, size accounting, similarity gates, and storage math. They are **test source, not passing test results** until run in Xcode. Follow TESTING.md and append real evidence to PROGRESS.md before submission.
