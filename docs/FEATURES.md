# PipSweep product features

PipSweep is now being prepared as a standalone product. Prior assignment restrictions are not the release specification.

| Feature | Current behavior |
| --- | --- |
| Similar photos | Matching previews and near-identical shots are suggestions. Recommended keeps favor favorites, resolution and recency. |
| Screenshots | Multi-selection and swipe review, with keep-one protection for matched groups. |
| Large videos | Known sizes sort largest first; unavailable sizes are disclosed. Preview and reviewed deletion are available. |
| Blurry photos | Conservative luminance/edge suggestions with overlapping regional checks for sharp subjects. |
| Contacts | Reviewed same-account merges and deletion. Conflicting single-value details block merging. Unsupported fields are disclosed. |
| Calendar | Eligible old, writable events; recurring events, invitations and read-only calendars are excluded. |
| Storage widget | Small and medium Home Screen widgets showing device capacity. |
| Activity | Local cleanup counts and estimated media bytes; history can be cleared in Settings. |
| Privacy and help | Offline privacy policy, configurable public support contact, permission shortcut and recovery guidance. |
| Mascot | Pip with a broom, gentle motion, blinking and Reduce Motion support. |
| Welcome | Introductory screen appears once per installation unless app preferences are removed. |

## Product direction

The first release centers on small, user-controlled reviews with an on-device workflow. Authentication, cloud sync, compression, a private vault and paid features are not implemented in this update. These are product decisions for a future release, not assignment prohibitions.

iOS does not expose unrestricted access to other apps' caches or system junk, so PipSweep does not offer or advertise cleaning them.

## What still needs release acceptance

Xcode build and XCTest results for these changes, a signed archive, real-iPhone acceptance, TestFlight feedback, current screenshots, verified public privacy/support URLs, and App Store Connect configuration remain required.
