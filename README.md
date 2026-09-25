# Clearspace

An iPhone storage cleaner built with SwiftUI, PhotoKit, and Vision. Everything is free and processed on the device. iOS 17+; iPhone only.

**Milestone 1: source implementation of storage dashboard, similar photos, and screenshots, with Photos permissions and safe review/delete.** This is not yet a submission-ready release: Xcode compilation, simulator tests, and real-iPhone validation are still required. See [PROGRESS.md](PROGRESS.md) for the exact status.

## Open on your Mac

1. Download or clone this repository.
2. Open `Clearspace.xcodeproj` in Xcode 15 or newer. No CocoaPods, packages, API keys, or project-generation tools are required.
3. Select the **Clearspace** scheme and an iPhone simulator, then press **⌘R**.
4. For a real iPhone: select the Clearspace target → Signing & Capabilities → choose your development team. Change the bundle identifier if Xcode requires a unique one. Connect and select your iPhone, enable Developer Mode if requested, and run.
5. Press **⌘U** for the included safety-rule unit tests. See [docs/TESTING.md](docs/TESTING.md) for the manual device tests.

The checked-in Xcode project is ready to open; `scripts/generate_project.py` is only needed after adding new Swift files outside Xcode or to regenerate the project. It uses Python's standard library.

## Try the core loop

1. On first launch, read the permission explanation and choose Photos access.
2. Choose full access or limited access to a disposable test album. Scan while the app is in the foreground.
3. Open **Similar photos**. Preview groups, see the recommended keep, then explicitly select suggestions or individual photos. At least one photo must remain in each group.
4. Open **Screenshots**. Select individual screenshots or select all, and inspect previews.
5. Tap **Review selection**. Check every item and size, then tap Delete and confirm. iOS asks for its own deletion approval. Cancelling either prompt preserves the library.
6. After success, scan again to refresh categories. Items remain in Photos' Recently Deleted; the app does not claim that device storage has increased immediately.

## What's included

- Real device used/free storage; explicit failure state.
- Locally available photo scan, progress, cancellation, and elapsed time.
- Global matching of normalized previews and conservative nearby-shot similarity suggestions.
- Favorite/resolution/recency based recommended keep; manual override while retaining one group member.
- Screenshot discovery, bulk selection, and expanded previews.
- On-device logical resource-byte counting, unknown-size reporting, and no fabricated storage numbers.
- Permission rationale, denied/restricted states, limited-library management, and invalidation after Photos changes.
- Final immutable review, stale-data validation, native deletion confirmation, and cancellation/error handling.
- Original name, stacked-card app icon, teal UI, semantic colors, dark appearance support, and accessibility labels.
- Xcode project, shared scheme, XCTest source, CI configuration, and progress documentation.

Large videos, duplicate contacts, and Contacts permissions belong to the next milestone. The dashboard labels those categories as unimplemented. All bonuses, paywalls, accounts, cloud sync, and other-app cache cleaning are excluded.

## Design decisions and limits

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before changing scan or deletion code. Read [docs/DECISIONS.md](docs/DECISIONS.md) for evaluation tradeoffs and Apple API references.

Similarity is a **review suggestion**, not proof of byte-identical files. The current threshold needs testing against real photos. Near-similarity comparisons are bounded to 24 recent anchors within 60 seconds; visually matching previews can match globally. Cloud-only resources are not downloaded and can be skipped or have unknown sizes. Resource sizes do not equal immediately reclaimable device storage.

## Continue this project with ChatGPT

Share the repository URL and say:

> Read PROGRESS.md and docs/ARCHITECTURE.md. Implement the next pending milestone. Update the status and verification evidence, and keep deletion safeguards intact.

Update `PROGRESS.md` after every milestone. Use the feature-task issue template for new work. Never mark an item device-verified without an actual iPhone test result.

## GitHub setup if this download is not yet connected

From this project folder, with GitHub CLI installed and signed in:

```bash
bash scripts/create_github_repo.sh
```

This creates **a private `Clearspace-iOS` repository in your authenticated account** and pushes the project. It never force-pushes or changes visibility. If that repository already exists, it stops so you can confirm the intended destination. Share the code with the evaluator when ready; private repositories require collaborator access.
