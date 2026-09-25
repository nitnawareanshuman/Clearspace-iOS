# Evaluation decisions

| Evaluation point | M1 choice | Tradeoff / remaining evidence |
|---|---|---|
| End-to-end core loop | Include permissions and review/delete alongside the first three features | Full brief still needs videos and contacts |
| Safety | Empty initial selection, one keep per group, immutable review, native approval, stale-data checks | Requires device cancellation and concurrent-change testing |
| Speed and accuracy | Local downsampled previews; bounded nearby comparisons; global normalized-preview lookup; actor work | Thresholds and throughput uncalibrated; misses are possible |
| Usability | Original teal design, two clear categories, explicit progress, previews and honest unknown states | Accessibility and visual QA require simulator/device |
| Scope and AI use | Build a coherent M1; document algorithm and missing features; no bonus work | AI-authored source must be built, tested, and understood by the submitter |

All processing is on device. There is no network client, tracking SDK, authentication, cloud synchronization, subscription, or paywall. PhotoKit download flags are false. System iCloud Photos may synchronize a user-approved deletion; the app explains this rather than claiming deletion is device-local.

## Apple API references consulted

- [PhotoKit resource manager](https://developer.apple.com/documentation/photos/phassetresourcemanager)
- [Resource data requests](https://developer.apple.com/documentation/photos/phassetresourcemanager/requestdata(for:options:datareceivedhandler:completionhandler:))
- [Vision image feature prints](https://developer.apple.com/documentation/vision/vngenerateimagefeatureprintrequest)
- [Analyzing image similarity](https://developer.apple.com/documentation/vision/analyzing-image-similarity-with-feature-print)
- [Required-reason API declarations](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype): disk-space reason `85F4.1` for displaying capacity information to the device user.

## What to explain in an interview

1. PhotoKit permission scopes and why limited access yields partial scan results.
2. A Vision feature-print distance measures visual similarity; it is not a trained duplicate classifier or a certainty score.
3. Why preview hashing, aspect ratio, perceptual hash, and a bounded time window reduce work and false positives.
4. Why keeping a favorite and requiring review is safer than auto-deletion.
5. Why resource sizes, iCloud originals, and Recently Deleted complicate storage estimates.
6. How callback cancellation races are resolved once, and why scan work is isolated from the UI.
7. What has not been tested yet. Never describe an unrun test as passing.
