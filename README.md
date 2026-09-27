# Clearspace

A private, on-device iPhone storage cleaner built with SwiftUI, PhotoKit, Vision and Contacts. iOS 17+, iPhone only. No third-party dependencies. Nothing is deleted without review and explicit approval.

## Run on your Mac

1. Open `Clearspace.xcodeproj` in **Xcode 16 or later**. The iOS 18 SDK is required to compile limited Contacts support; deployment remains iOS 17.
2. Select Clearspace → Signing & Capabilities → your development team. Adjust the bundle identifier if necessary.
3. Select an iPhone or simulator and Run. Tap **Make some room** on the welcome screen.
4. Choose Photos access when scanning; Contacts access is requested separately inside Duplicate contacts.
5. Run **Product → Test** (⌘U). Before submission, test on a real iPhone with disposable media and contacts.

## Features

- Used/free device storage and cleanup candidate resource totals.
- Similar-photo groups, recommended keeps and safe multi-selection.
- Screenshots with selection and preview.
- Videos ordered by size, local playback, selection and review. All accessible videos are included; unknown sizes appear last.
- Possible duplicate contacts based on shared full names, phones or emails. Compare individual cards, review a merge into a chosen keeper, or delete selected copies while keeping at least one per group.
- Final review of selected media/contact cards, kept contacts and explicit destructive confirmation.
- Independent Photos/Contacts permissions, including denied, restricted and limited states.

Confirmed media deletion preserves remaining category results. Empty categories offer an in-place scan-again action. A mascot popup reports actual cleanup completion.

**Pip** gently breathes and blinks at idle and moves within a fixed frame during scanning and cleanup. Pip is an original animated SwiftUI mascot on the welcome/splash screen, dashboard and loading states. It stays crisp at every size, requires no plugin or download, and respects Reduce Motion.

## Important behavior

Sizes are logical media resource bytes, not guaranteed recovered device space. Photos uses Recently Deleted and iCloud Photos may synchronize deletion. Clearspace does not empty Recently Deleted.

Contacts offer **reviewed merge** and **delete**. Merging combines supported fields in a chosen card within one account; conflicting single-value details block the merge. Notes cannot be read or copied, and account-specific fields/group membership are not transferred; the review requires acknowledgement before removing source cards. Shared details are suggestions only; no cards are preselected. Deletion removes the entire selected card, including notes/fields not displayed, and does not copy details to kept contacts. The app provides the final confirmation because Contacts has no second system prompt. There is no app-level undo. Contact sizes are unavailable and never fabricated.

All content stays on-device. Cloud-only media is not downloaded and may lack a preview/size. Public resource streaming avoids private APIs but can be slow for large videos. Timeouts remain unknown sizes. Similarity is heuristic; inspect each suggestion.

## Structure

```
Clearspace/
  App/                 App entry and observable stores
  Core/Models/         Models and pure safety/matching rules
  Core/Services/       PhotoKit, Vision and Contacts work
  DesignSystem/        Shared cards, thumbnails and Pip mascot
  Features/Launch/     Splash/welcome view
  Features/Dashboard/ Storage and category overview
  Features/Photos/    Similar photos and screenshots
  Features/Videos/    Ordered videos and playback
  Features/Contacts/  Permission, selection and contact review
  Features/Review/    Final media deletion review
  Resources/           Assets, Info.plist and privacy manifest
ClearspaceTests/       Selection, contact matching and video sorting tests
```

Xcode groups mirror these folders. After adding files, run `python3 scripts/generate_project.py`; no XcodeGen installation is needed. The shared scheme and existing GitHub Actions workflow build/test without signing.

See [PROGRESS.md](PROGRESS.md), [testing](docs/TESTING.md) and [validation evidence](docs/VALIDATION.md). Simulator success does not replace the assignment's real-iPhone walkthrough.

