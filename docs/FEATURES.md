# Assignment coverage

This mapping describes source implementation, not completed device acceptance. The assignment requires an iPhone app on iOS 17+, on-device processing, reviewed deletion, and a real-iPhone walkthrough.

| Requirement | Current implementation | Important limit |
| --- | --- | --- |
| Storage dashboard | Used/free capacity, per-media-category estimates, deduplicated combined estimate | Resource bytes do not equal immediate recovered device space. |
| Similar photos | Matching previews and conservative near-shot groups; recommended keep | Preview matching is not full-file equality; near matching has bounded time/anchor windows. |
| Screenshots | Accessible, non-hidden screenshots with multi-selection and previews | Bulk selection keeps one member of matching groups and skips read-only media. |
| Large videos | All accessible non-hidden videos, preview, descending known sizes | Unknown sizes remain visible last; cloud-only playback may be unavailable. |
| Duplicate contacts | Candidate groups and reviewed deletion | Implements the brief's delete alternative; no merging. |
| Review before delete | Exact selections, media estimates, survivor checks, explicit confirmation | Contacts/calendar have no additional system deletion prompt; no app undo. |
| Permissions | Independent Photos, Contacts, and Calendar explanations and states | Limited Contacts requires iOS 18+; Calendar needs full event access. |

## Bonuses

| Bonus | Status |
| --- | --- |
| Swipe-to-keep-or-delete | Implemented as selection with Undo and final review. |
| Blurry photo detection | Implemented as a manual-review heuristic. |
| Calendar cleanup | Implemented for eligible events from the past year ending over 30 days ago. |
| Home Screen storage widget | Implemented for small and medium sizes; verify installation and gallery discovery on device. |
| Space-freed summary | Implemented as completed cleanup counts and estimated media removed. |
| Video compression | Not implemented. |
| PIN / Face ID vault | Not implemented. |
| TestFlight build | No distribution link supplied or verified in this review. |

Payments, paywalls, email cleanup, clearing other apps' caches, login/cloud sync, and iPad/Watch/Mac versions are outside the assignment scope.

## Submission

- Repository containing the Xcode project.
- A 2–3 minute walkthrough on a real iPhone using non-private sample content.
- A note under 150 words covering tools used, working features, missing features, and the hardest problem solved. Describe actual testing honestly.
- TestFlight link only if a build is available.
