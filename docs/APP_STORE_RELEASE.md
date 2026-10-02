# PipSweep release and submission guide

Prepared 2 October 2026 from repository main commit 3cedd7e2bacd4fbc0f2f5299fc7fde03bb719578.

## Identity and build

- App name: **PipSweep**
- Subtitle: **Small sessions. More space.**
- Primary category: **Utilities**
- Version/build: **1.0.0 (2)** in both the app and widget.
- Minimum device OS: iOS 17.
- Submission build SDK: iOS 26 or newer, using a compatible stable Xcode release.
- Existing scheme/module: Clearspace.
- Existing app bundle identifier: com.anshumannitnaware.Clearspace.
- Existing extension bundle identifier: com.anshumannitnaware.Clearspace.ClearspaceWidget.

The internal identifiers are preserved for compatibility. A display-name change does not require new bundle identifiers. Register the app and extension under the authorized publishing team; if that team requires different identifiers, keep the extension prefixed by the app identifier and update both targets.

Public searches on 2 October 2026 found no exact PipSweep App Store listing. This cannot detect every storefront, unpublished reservation or other rights. Confirm the exact name when creating the app record in App Store Connect.

## Using someone else's Developer Program membership

Ask the account holder to invite you through **App Store Connect → Users and Access** with the role needed for this app. Use your own Apple Account for that invitation.

An organization membership can grant development-team access. An individual membership's additional users get App Store Connect access only; the account holder must handle signing or authorized signing assets and upload arrangements. A Team ID alone does not grant permission to sign.

Apps published under that membership appear under its seller identity. Agree with the holder on distribution, support and future updates. Set signing on both app and widget before archiving.

Sources:
- https://developer.apple.com/help/app-store-connect/manage-your-team/add-and-edit-users/
- https://developer.apple.com/help/account/access/roles/
- https://developer.apple.com/programs/enroll/

## Privacy and support pages

The app contains an offline policy in Settings → Privacy policy. This repository is private, so its issue tracker is not a suitable public support channel.

Public page templates:
- docs/pipsweep/privacy.html
- docs/pipsweep/index.html
- docs/pipsweep/pip-icon.png

Before release, choose a monitored public support email or HTTPS support service. Set **PipSweepSupportURL** in Clearspace/Resources/Info.plist to its `mailto:` or `https://` URL. Until configured, the app omits the external contact link and keeps its offline help available.

Replace the clearly marked contact setup block in docs/pipsweep/index.html with that contact link. Publish these three page files on a public static host or a separate public support repository. The app's private source repository does not need to become public. If using GitHub Pages, check the hosting plan and repository visibility requirements first.

Use the actual deployed privacy.html URL for App Store Connect's **Privacy Policy URL**, and the deployed support index page for **Support URL**. No public pages or domain are created by this update. Open both URLs without signing in, test the contact link, and make sure the maintainer/publisher information matches the final publishing arrangement.

The current binary processes content only on device, uses no developer analytics/ad SDK and has no backend. **Data Not Collected** is the likely App Privacy answer for this code. Reassess after any SDK, network feature, analytics or monetization change. Privacy manifests are already included in app and widget.

## App Store description draft

Meet Pip, your little tidy companion. PipSweep helps you review clutter on your iPhone and make room through small, deliberate choices.

Start with Pip's ten-shot tidy: review up to ten screenshots at a time, oldest first. Keep useful memories, queue temporary clutter, preview details and undo a swipe before the final review.

Explore similar-photo suggestions, screenshots, possible blurry shots and large videos with previews. Review duplicate contact cards and eligible old calendar events when you choose those features. Track completed cleanup activity and see device storage from a Home Screen widget.

Your photos, contacts and events are processed on your iPhone. No app account is required. Every removal needs your approval.

Storage totals are estimates. Recently Deleted, iCloud settings and unavailable media can affect the space recovered. Similar and blurry results are suggestions for your inspection. Contact merging has limits for notes and account-specific details; these are explained before approval.

## Keywords draft

photo,screenshot,duplicate,similar,blur,video,storage,tidy,contacts,calendar

## Notes for Review draft

PipSweep is an iPhone organizer built around optional, bounded reviews. The ten-shot tidy offers up to ten accessible screenshots, oldest first, with per-item Keep/Remove, preview, Undo, and a separate deletion review. Favorites are excluded from this session. Matched groups must retain at least one item.

No login or developer backend is required. Photos, Contacts and Calendar permission prompts are independent. Limited Photos and Contacts access are handled. Photos and video removal also requires the system Photos confirmation.

Settings contains the offline privacy policy, recovery guidance and local-history controls. Configure its public support contact before submission. The storage widget is embedded with the app.

To test the ten-shot tidy, add screenshots to the device, grant Photos access, scan, then open Pip's ten-shot tidy. Review Remove/Keep choices and approve or cancel the final review. Contact and Calendar features can be tested separately using disposable records. No demo credentials are needed.

## Release acceptance

1. Apply the files and select the authorized team on app and widget.
2. Run Product → Test in Xcode; investigate every failure.
3. Build the Release configuration for a real iPhone.
4. Complete docs/TESTING.md on a real iPhone using disposable content.
5. Capture new PipSweep screenshots; existing Clearspace screenshots are historical.
6. Archive in Xcode, validate and upload to App Store Connect.
7. Distribute through TestFlight and resolve observed issues.
8. Configure the in-app support contact, publish and verify the support/privacy pages, and complete metadata, age-rating and privacy questions.
9. Submit one complete app with clear, accurate review notes.

A mascot/name change alone does not establish a meaningfully different product. Demonstrate the small-session workflow, deliberate approvals, transparency and tested quality without claiming these are exclusive features or guaranteeing approval under guideline 4.3.

Apple sources:
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/news/?id=ueeok6yw
- https://developer.apple.com/app-store/app-privacy-details/
- https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/
- https://support.apple.com/en-us/104967
