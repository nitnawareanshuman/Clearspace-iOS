# Bonus branch changes — Clearspace

This branch implements the Storage Cleaner assignment's swipe-to-keep-or-delete bonus and mascot waiting UI. The existing deletion flow remains the only place where PhotoKit deletion is requested; swipe mode only builds the review selection.

## Created
- `docs/BONUS_CHANGES.md` — this change log and simulator test checklist.

## Modified
- `Clearspace/Features/Photos/PhotoCollectionView.swift`
  - Adds entry points for Swipe mode.
  - Adds the swipe card interaction: swipe right to keep, left to queue for deletion.
  - Adds Keep/Delete buttons and a Review button.
  - Keeps the existing final review/deletion flow.
  - Passes similar-photo groups into swipe mode so the last photo in a group cannot be queued for deletion.
- `Clearspace/DesignSystem/PipMascot.swift`
  - Adds `MascotWaitingView` with Pip, progress, and a clock badge.
  - Adds `MascotWaitingPopup` for scan-time waiting UI.
  - Uses the same waiting component for video-loading states.
- `Clearspace/Features/Dashboard/DashboardView.swift`
  - Shows the mascot waiting popup while a library scan is running.
- `Clearspace/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
  - Replaced with a clean mascot-based 1024×1024 app icon.

## Simulator check
1. Checkout the `bonus` branch.
2. Run the `Clearspace` scheme on an iPhone simulator.
3. Add/import a few photos into the simulator Photos library.
4. Run a scan.
5. Open **Similar photos** or **Screenshots** and tap the hand icon / **Swipe mode**.
6. Swipe right to keep and left to queue deletion.
7. Tap **Review** and verify the normal review screen shows the queued items.
8. Confirm that no deletion happens during swiping.

Note: the simulator needs sample media to make the cleaner results useful. The assignment also calls for real-iPhone testing with a real photo library before submission.

