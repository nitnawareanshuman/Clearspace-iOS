# Design decisions

| Decision | Reason and tradeoff |
| --- | --- |
| On-device system frameworks | Photos, Contacts, EventKit, Vision, and WidgetKit provide native access without a backend or uploads. |
| Review is mandatory | Matching is imperfect. Selections and swipes only prepare a draft; destructive operations require explicit approval. |
| Keep one member of each matched group | Reduces accidental loss while letting the user choose which copy survives. Favorites are excluded from similar/blur suggestions, but can be selected manually with a review warning. |
| Bounded similarity comparisons | Limits feature-print memory and comparisons. Near duplicates outside 60 seconds or the 24-anchor window can be missed. |
| Preview-based matching | Faster and smaller than full-file comparisons. Matching previews do not prove identical originals, Live Photo motion, or metadata. |
| Orientation-aware image analysis | The fingerprint should represent what the user sees. UIKit drawing applies rotation and mirroring before hashing and Vision analysis. |
| Conservative blur suggestions | Global and regional edge variance help retain sharp subjects against soft backgrounds. Intentional blur may be suggested; low-detail scenes may be skipped. |
| Stream resource sizes with public APIs | Avoids private file-size access and whole-video buffers. Initial scans can be slow; inaccessible or timed-out sizes remain unknown. |
| Contact deletion without merging | The assignment permits either. Automatic merging can lose conflicting fields or inaccessible notes; users review whole-card deletion instead. |
| Narrow calendar eligibility | Excluding recurring, detached, invitation, recent, and read-only events reduces deletion ambiguity. |
| Counts for contacts/calendar | iOS exposes no reliable per-item storage saving for these domains. |
| Local receipt history | Stores dates, counts, and estimated bytes only. Restoring content outside the app does not reverse historical activity. |
| Independent widget | Device-capacity display needs no photo permission or shared media database. Refresh timing remains system-controlled. |
| Original SwiftUI mascot | Pip scales without image downloads and respects Reduce Motion and app activity. The README reuses the app icon. |

## Remaining limits

Hidden media is excluded. Downloads are disabled, so iCloud-only content can be unavailable. System account synchronization still applies to user-approved deletions even though Clearspace performs no uploads itself. Photos may retain deleted media in Recently Deleted; capacity can change for unrelated reasons.

Preflight snapshot checks cannot lock the system libraries while another app or account changes them. Permission, provider, performance, and visual behavior require real-device acceptance. The widget must be installed with the host app and tested in the Home Screen gallery.

## API reference

- [UIImage drawing and orientation](https://developer.apple.com/documentation/uikit/uiimage/draw(in:))
- [Photos](https://developer.apple.com/documentation/photos)
- [Contacts](https://developer.apple.com/documentation/contacts)
- [EventKit](https://developer.apple.com/documentation/eventkit)
- [WidgetKit](https://developer.apple.com/documentation/widgetkit)
