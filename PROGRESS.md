# Clearspace progress

All seven core features have implementations. Device acceptance testing remains required.

The 26 September must-have audit and focused bug fixes are documented in
[docs/CORE_AUDIT.md](docs/CORE_AUDIT.md), including remaining limitations and the real-iPhone checklist.

| Core feature | Implemented behavior |
| --- | --- |
| Dashboard | Used/free storage; candidate media bytes; contact counts with no invented size estimate |
| Similar photos | Groups, recommended keeps, preview, selection; at least one remains |
| Screenshots | Multi-selection, preview and review |
| Large videos | Descending known sizes, unknown last, playback and confirmed deletion |
| Duplicate contacts | Shared name/phone/email candidates, individual cards, select copies to delete, keep one per group |
| Review before delete | Exact media/contact selection, kept contacts, explicit approval and stale-review protection |
| Permissions | Separate Photos/Contacts explanations; denied/restricted/limited handling |

UI: Pip mascot in welcome, dashboard and loading; category colors, grouped cards, rounded typography, light/dark appearance and Reduce Motion. Xcode now mirrors App, Core, DesignSystem, Features and Resources folders.

Deliberate limits: Contacts supports deletion rather than merging (the brief permits either). No auto-selection or copying conflicting details. Notes require a special entitlement and are not read. Public media size measurement can be slow; unavailable sizes remain unknown. No bonuses, subscriptions, account login, cache cleaning or cloud uploads.

## Before submission

- [ ] Pass GitHub Actions simulator build and XCTest.
- [ ] Complete docs/TESTING.md on a real iPhone; record model, OS, library size and scan time.
- [ ] Record a 2–3 minute walkthrough using non-private content.
- [ ] Submit repository link and truthful note under 150 words.
