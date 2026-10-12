# Optional registered-mat unlock

## Approved direction

The user selected matching their own registered prayer mat, keeping the feature optional and processing photos on the device. This extends the existing per-prayer unlock and does not infer prayer completion.

## Experience

- Off by default. Settings offers registration, enable/disable, replacement and removal of one mat. Registration is optional during setup and never required for membership or manual unlock.
- Registration uses a fresh rear-camera photo. Ask the user to fill the frame with the unfolded mat, photographed from above in good light. Review the photo before saving.
- Registration saves a Vision image feature print, not the photograph. A saved mat can be disabled and re-enabled. Removing it also disables the feature.
- When enabled with a valid registration, Today offers “Unlock with prayer mat” during an unreleased current prayer. The user takes a fresh photo with similar framing, reviews it and explicitly requests comparison.
- A match releases only the prayer event that was current when the flow opened. It does not mark the prayer completed or release the next prayer. Refresh the schedule before applying the result. An event change or lost eligibility cancels the release.
- No match, cancellation, denied camera permission and unavailable camera provide a clear retry/manual-unlock path. Existing finish/already-prayed/manual-unlock/pause behaviour remains available.

## Local comparison and storage

Use Apple's Vision feature-print request with a pinned revision, consistent orientation and crop/scale behaviour. Compare the stored print to the current capture off the main actor. A finite distance within a conservative initial threshold is a match; invalid inputs, incompatible revisions and processing failures never grant photo unlock. The initial threshold is an experimental parameter, not a calibrated promise of recognition accuracy.

Store a versioned profile containing the feature-print archive, request revision, registration identifier and enabled flag in app-private Application Support with complete file protection. Write atomically and mark the profile/directory excluded from backup after each write. Apple's backup exclusion is guidance, not an absolute guarantee. Do not put the profile into the App Group or UserDefaults. Do not send photos or feature prints to servers, analytics or logs, or add them to Photos. Captures stay in memory only for the review/comparison flow and are released on exit.

Reject corrupt, oversized, unsupported or unreadable profiles. Recover by offering registration again, with ordinary unlock still available. Registration becomes active only after a successful save. Replacing a registration invalidates in-flight comparisons against the prior identifier. Erase local data also removes the mat profile; deletion failures must be surfaced and must not silently report successful erasure.

This matches the user's chosen reference object. It does not classify prayer mats, prove that the photographed object is a physical mat, or verify worship. A photograph of a photograph can defeat it. UI and release notes must not imply security or prayer verification.

## Boundaries

- `MatImageMatcher`: local Vision extraction and comparison using transferable image bytes.
- `RegisteredMatStore`: observable local registration, persistence, optional enablement and deletion.
- Camera/review components: camera permission requested only when capture is initiated; native camera, cancellation and image review.
- Settings/Today integration: enrollment management and guarded release through the existing session/runtime.

Minimum iOS remains 18. No network dependency, backend, Photos-library permission, worship analytics or changes to the subscription gate.

## Validation

Automated tests cover feature extraction/archive compatibility, same-image matching, unrelated-image rejection, malformed input, storage/relaunch/disable/remove, backup exclusion, failed writes, erased/replaced registration and stale prayer results. Synthetic image tests prove wiring and basic comparison only. Use actual iPhone photos of several patterned and plain mats across lighting, framing, rotation and camera models to calibrate recognition before claiming device accuracy. Real Screen Time release and permission flows require physical-device acceptance.

## References

- [Apple: analyzing image similarity with feature prints](https://developer.apple.com/documentation/vision/analyzing-image-similarity-with-feature-print)
- [Apple: optimizing app data for iCloud backup](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup)
