# Registered Mat Unlock Implementation Plan

> **For agentic workers:** Use the executing-plans workflow inline in the existing isolated worktree. Track the tasks below and verify the final diff before reporting completion.

**Goal:** Add an optional, on-device camera unlock using the user's registered mat.

**Architecture:** Store a versioned Vision feature print in app-private protected storage. Shared observable registration state feeds Settings and Today; the successful comparison uses a guarded per-event session release.

**Tech Stack:** Swift 6, SwiftUI, UIKit camera picker, AVFoundation permission, Vision revision 2, XCTest, XcodeGen.

## Global constraints

- Minimum iOS 18; native existing app and subscription gate.
- Feature off by default; manual unlock remains available.
- No saved raw photos, network requests, Photos-library permission or prayer-completion inference.
- Reject stale event and registration results; failure never photo-unlocks.
- Synthetic image tests are distinct from real-mat/device validation.

## Task 1: Matching, persistence and guarded release

Files: `ios/PrayerFocus/PrayerFocusApp/Services/MatImageMatcher.swift`, `RegisteredMatStore.swift`, `Domain/PrayerFocusSession.swift`, and `PrayerFocusTests/RegisteredMatTests.swift`.

- [x] Write tests for disabled default, persistence across relaunch, disable/re-enable, removal, failed writes, backup exclusion, malformed profile/image, real Vision extraction/comparison, and stale event release.
- [x] Generate the Xcode project and run the narrow tests; observe missing-feature failures.
- [x] Implement `MatImageMatcher.featurePrint(for: Data) -> Data`, `matches(image: Data, reference: Data) -> Bool`, `RegisteredMatStore.register(featurePrint: Data)`, `setEnabled(Bool)`, `remove()` and `PrayerFocusSession.unlockForMatchedMat(eventID: String) -> Bool`.
- [ ] Require a passing image-comparison integration check on iPhone. Simulator comparison remains blocked by inaccurate Vision inference; the failure remains visible in the test suite.

## Task 2: Camera, enrollment and Today

Files: `PrayerFocusApp/Features/MatUnlock/`, `Features/Settings/FocusSettingsView.swift`, `Features/Today/TodayView.swift`, `App/PrayerFocusApp.swift`, `project.yml` and generated `PrayerFocus.xcodeproj/project.pbxproj`.

- [x] Add camera-only capture with user-triggered permission, explicit review, retry, cancel and unavailable/denied states. Run Vision away from the main actor and discard capture bytes when leaving the flow.
- [x] Add registration/replacement/removal/enable controls to Settings. Inject shared registration into the app and previews. On erase, require successful mat deletion before claiming complete erasure.
- [x] Add optional Today action. Capture event/profile identity, refresh prayer schedule after comparison, check enabled/current identities and membership, then call the guarded release method.
- [x] Add `NSCameraUsageDescription` to the source project configuration and regenerate; build the simulator target.

## Task 3: Privacy and verification

Files: `MembershipPaywallView.swift` privacy view, `docs/release/privacy-policy-draft.md`, `front/src/pages/privacy.astro`, `ios/PrayerFocus/README.md`, `docs/release/physical-device-qa.md`.

- [x] Explain on-device processing, stored fingerprint, optional camera and deletion; retain the backup caveat.
- [x] Run strict Swift formatting/lint, relevant unit tests, a Release simulator build and `git diff --check`.
- [x] Review event/registration races, cancellation, persistence errors and preview environments in the final diff. Record real-mat threshold calibration and physical camera/Screen Time acceptance as outstanding, with no invented device results.

## Execution record

Implemented the optional registered-mat flow and camera-only review, protected local fingerprint storage, per-event release guards, deletion controls and privacy copy. XcodeGen generation, strict Swift lint, the final Release simulator build (no diagnostics), frontend type/format checks, frontend tests (3 passed), and `git diff --check` passed. Source review found no confirmed cancellation, stale-event, stale-registration or storage activation defects.

The broad simulator regression run executed 36 tests: 35 passed and one image-comparison test failed. The registration UI, malformed/unsupported profile handling, failed writes, backup exclusion, disable/remove/relaunch, prayer schedule and focus release checks passed. The remaining test receives nearly identical Vision prints for visibly different synthetic JPEGs on iOS 26.5/27 simulators. A native macOS check using the final production matcher and the same JPEG bytes accepted the same image and rejected the unrelated image (distance 0.9183653). This confirms comparison wiring, not physical iPhone accuracy. Simulator CPU selection allows inference to run, but software Core Image rendering, explicit BGRA buffers and alternate scaling did not correct the results. Those ineffective workarounds were removed; the comparison test remains enabled and failing rather than weakening its assertion or changing the threshold. The installed Vision SDK warns that simulator results can be inaccurate because of Core Image pixel-format rendering.

The 0.35 threshold remains experimental. Physical iPhone camera permissions/capture, real-mat calibration, and actual Screen Time release remain unverified in the device acceptance log. This work is an initial implementation, not release/device acceptance. The public privacy page source was updated locally, not deployed.

## PR verification, 2026-10-12

Fresh strict Swift formatting, vendored Adhan calculation tests, frontend checks/tests (3 passed), privacy-page formatting and an unsigned generic Release simulator build passed. App-test rerun was attempted but blocked because this machine now has no installed simulator runtimes or available simulators. The 2026-10-11 broad result remains 35 passed / 1 failed; it is not a fresh passing app-suite result. Open as a draft with simulator comparison and physical-device calibration unresolved.

## CI repair, 2026-10-12

The remote native job confirmed the unrelated-image failure with identical Vision vectors and unsupported RGBA pixel-buffer rendering; the other four PR checks passed. The comparison test was moved to shared `TestSupport/MatImageMatcherTests.swift`, compiled both into the iOS test target and a host-only macOS `PrayerFocusVisionTests` target using the production matcher source. CI now requires the native macOS comparison step before its existing simulator suites. Only the unsupported simulator comparison is explicitly skipped; the same assertions remain active on native macOS and physical iPhones. The matcher, threshold and app behavior were not changed. Device calibration remains pending.

Local repair validation passed: required macOS Vision XCTest (1 test, zero failures), strict Swift formatting including TestSupport, generated Xcode project and unsigned generic iOS simulator build-for-testing for both simulator architectures. The local machine still has no simulator runtime, so actual simulator execution is verified through remote CI.
