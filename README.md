<p align="center">
  <img src="Clearspace/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="112" alt="Pip holding a broom">
</p>

# PipSweep

A native iPhone photo and storage organizer with Pip, a small teal companion with a broom. Make room through deliberate choices: scan accessible content, review suggestions, and approve each removal.


Built by **Anshuman Nitnaware**. The current release has no account requirement, advertising, subscriptions or backend.

## Features

- Device storage dashboard with per-category media estimates.
- Similar-photo suggestions, screenshots, blurry-photo suggestions and large-video previews.
- Reviewed contact merges and deletion, with account and field-conflict checks.
- Optional calendar cleanup for eligible old events.
- Small and medium storage widgets.
- Local cleanup history with a clear-history control.
- Settings, offline privacy policy, configurable support contact and cleanup/recovery guide.
- Pip's broom moves subtly while cleaning; mascot and swipe motion respect Reduce Motion.

## Run and test

1. Open **Clearspace.xcodeproj** in **Xcode 26 or newer** with an iOS 26 or newer SDK.
2. Select the **Clearspace** scheme and an iPhone running iOS 17 or later.
3. Choose the authorized signing team for **Clearspace** and **ClearspaceWidgetExtension**.
4. Run **Product → Test**, then test on a real iPhone with disposable content.
5. Add the widget from the Home Screen gallery by searching for **PipSweep**.

The existing project, scheme, module and bundle identifiers are retained so the update installs into the existing project. The app and widget display PipSweep and use version **1.0.0 (2)**.

There are no third-party runtime packages. GitHub Actions checks the selected SDK, builds simulator and Release configurations, and runs the XCTest suite.

## Privacy and cleanup

Processing runs on the iPhone. PipSweep does not upload photos, contact cards or event contents. Cloud-only media is not downloaded. Hidden media is excluded.

No swipe or selection deletes anything. Final review is required; media also uses Apple's Photos confirmation. System accounts may sync approved changes across devices. Recently Deleted can delay reclaimed device space. Displayed bytes estimate media content rather than immediate free capacity.

Contact notes, account-specific fields and group membership are not transferred by merging. Review these in Contacts before approving. PipSweep has no undo for contact or calendar changes.

## Release status

This is release preparation, not an App Store approval or a verified signed build. The local validation record distinguishes source checks from Xcode and device tests. Name availability must be confirmed in App Store Connect.

Public privacy and support page templates are prepared in **docs/pipsweep/**. Add a monitored support contact, configure `PipSweepSupportURL` in Info.plist, then publish and verify the pages before entering their URLs in App Store Connect. The private repository's issue tracker is not used as public support.

## Documentation

- [Release and submission guide](docs/APP_STORE_RELEASE.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Product features](docs/FEATURES.md)
- [Design decisions and limitations](docs/DECISIONS.md)
- [Acceptance testing](docs/TESTING.md)
- [Screenshots to capture](docs/SCREENSHOTS.md)
- [Validation record](docs/VALIDATION.md)
