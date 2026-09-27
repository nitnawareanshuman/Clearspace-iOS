# Decisions

- Extend existing media review and safeguards to videos.
- Include all accessible videos without an arbitrary cutoff; known sizes descend and unknown sizes remain visible last.
- Use public PhotoKit streaming, not private fileSize KVC or in-memory video buffers. Disable downloads and disclose unknown measurements.
- Offer same-account contact merging with keeper selection, combined-card preview and final confirmation. Block conflicting single-value details. Explicitly disclose inaccessible notes and account-specific fields/group membership before source-card removal; do not claim those are transferred.
- Enumerate individual contact records, never assume a shared name/number means the same person, and never preselect contacts.
- Keep Photos and Contacts permission flows independent. Support limited Contacts on iOS 18+ and deployment on iOS 17.
- Report no made-up contact storage savings.
- Draw original mascot Pip in SwiftUI: reusable, scalable, no dependencies; respect Reduce Motion.
- Splash/welcome has an immediate continue button, with no artificial loading delay.
- Generate nested Xcode groups and group assets/plists under Resources.
- Finish safe core features before bonuses. Real-device testing remains necessary.

Apple API references:

- https://developer.apple.com/documentation/photos/phimagemanager/requestplayeritem(forvideo:options:resulthandler:)
- https://developer.apple.com/documentation/contacts/cncontactstore
- https://developer.apple.com/documentation/contacts/cnsaverequest

