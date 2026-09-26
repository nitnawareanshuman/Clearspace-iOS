# Validation evidence

Local checks cover Swift syntax parsing (not SDK type-checking), Xcode object/source consistency, plist/asset JSON/scheme parsing, a single deletion site per store, disabled network downloads, no private size KVC, deterministic project generation and whitespace.

This environment is Linux without Xcode or an iOS simulator. GitHub Actions on the pull request is the source of truth for Apple SDK compilation and XCTest. Static checks alone do not prove a passing build.

Real-iPhone UI, permissions, video playback, actual deletion, provider behavior and large-library performance are not tested here. Follow TESTING.md before submission. Implemented is not the same as device-validated.
