# SalahSide for iPhone

Native SwiftUI app for calculated prayer times, optional Screen Time focus, private self-reported check-ins and daily affirmation widgets. The public name is SalahSide; the Xcode project, bundle/product IDs and existing URL scheme retain PrayerFocus.

## Current implementation

- Approved arch-and-mosque Today/paywall artwork and an opaque 1024px app icon.
- Setup before membership, with persisted city/method, standard/Hanafi Asr, high-latitude rule, minute adjustments, focus switches and app selection.
- Five prayer times calculated on device for London, New York, Toronto, Dubai and Kuala Lumpur, using the selected city's Gregorian calendar and time zone. A pinned MIT-licensed Adhan 1.5.0 package and its reference fixtures are vendored in `Vendor/Adhan` for offline builds.
- Explicit check-ins, already prayed and unlock. Earlier prayers are never inferred complete. Previous Isha remains current across midnight until Fajr; the Today list uses today's city-local date.
- Optional registered-mat photo unlock: register one mat in Settings, then compare a fresh camera photo on device using Vision. Only a protected comparison fingerprint is persisted; captured photos are not saved or uploaded. Disable, replace or remove registration in Settings. A match releases only the captured current prayer without marking it complete; cancellation, mismatch and changed prayer/registration do not release focus. Manual unlock remains available.
- Optional prayer-start notifications for the next seven days, bounded by verified membership expiration. Updates are serialized; disabling notifications or losing access removes app-owned pending requests. Open the app to refresh the horizon.
- Family Controls individual authorization and Apple's app/category/website picker.
- A named Managed Settings store, bounded Device Activity monitors, a prayer-aware shield and a shield action. Finish, already prayed, unlock, pause, a disabled next prayer, permission loss and invalid/expired state clear app-owned restrictions.
- File-locked, versioned App Group focus state protects against concurrent app/extension writes and repeated delivery of released events. Scheduling failures stop app-owned monitors and clear app-owned settings.
- One-hour pause/manual resume and erase-local-data action. Erasing returns even an active member to setup and does not cancel their Apple subscription or erase existing backups.
- Verified StoreKit membership, restore and eligibility-based three-day introductory trial. Paywall has no close/swipe escape while access is unverified; setup review and Privacy remain accessible.
- Thirty original English affirmations, small/medium Home Screen and rectangular Lock Screen widgets, expiration-aware timelines and membership-gated deep links.
- Privacy manifests in the app and extensions; required UserDefaults reasons cover own-app and App Group settings. No advertising or behavioral analytics SDK.

## Membership and identity

Product IDs remain `com.marsolab.PrayerFocus.yearly` and `com.marsolab.PrayerFocus.monthly`. Configure both in one App Store Connect subscription group with year/month durations and **Free, 3 Days** introductory offers for the intended storefronts. Local preview prices are $35.88/year and $3.99/month; choose supported live Apple price points before release. Production copy always uses localized StoreKit prices and actual eligibility. The full annual charge is shown, and its optional monthly equivalent is hidden if numeric/display metadata disagree.

Test fixtures are included only in test targets. No local `.storekit` file is bundled in the release app. Local tests do not configure App Store Connect or prove sandbox billing.

| Target | Bundle ID | Capabilities |
|---|---|---|
| App | `com.marsolab.PrayerFocus` | Family Controls, App Group |
| Widgets | `com.marsolab.PrayerFocus.Widgets` | App Group |
| Monitor | `com.marsolab.PrayerFocus.Monitor` | Family Controls, App Group |
| Shield configuration | `com.marsolab.PrayerFocus.Shield` | Family Controls, App Group |
| Shield action | `com.marsolab.PrayerFocus.ShieldAction` | Family Controls |

App Group: `group.com.marsolab.PrayerFocus`. Use one real Apple Developer team and matching profiles. Request Family Controls distribution approval for the app and all three Screen Time extensions. On iOS 26.5+, the shield's Open SalahSide action uses Apple's supported `openParentalControlsApp`; earlier iOS explains the manual return path.

The widget deep link remains `prayerfocus://daily-affirmation`. Missing/malformed/expired membership locks widgets. Refund/revocation awareness requires a fresh app entitlement check; offline extensions can only rely on the last verified snapshot until its expiration. WidgetKit controls actual refresh timing.

## Local validation

Use Xcode 26.5+ or Xcode 27, with an installed iPhone simulator and XcodeGen. The project deploys to iOS 18+ and availability-guards newer APIs. CI uses the documented macOS 26 image with Xcode 26.6; its workflow does not upload builds.

```sh
cd ios/PrayerFocus
xcodegen generate
xcrun swift-format lint --strict --recursive --configuration .swift-format \
  PrayerFocusApp Shared PrayerFocusWidgets PrayerFocusMonitor PrayerFocusShield \
  PrayerFocusShieldAction PrayerFocusTests PrayerFocusUITests TestSupport
swift test --package-path Vendor/Adhan
xcodebuild -project PrayerFocus.xcodeproj -scheme PrayerFocusVision \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO test
SALAH_SIM_ID=$(python3 scripts/select_simulator.py)
xcodebuild -project PrayerFocus.xcodeproj -scheme PrayerFocus \
  -testPlan PrayerFocusWidgets -only-testing:PrayerFocusTests \
  -destination "platform=iOS Simulator,id=$SALAH_SIM_ID" \
  -parallel-testing-enabled NO test
```

Run `-testPlan PrayerFocus` for setup, trial, purchase/restore, paywall, Privacy and local deletion UI. Run `-testPlan PrayerFocusStoreKit` for widget subscription expiry and deep-link integration. Run StoreKit plans sequentially with normal simulator signing. Disabling code signing prevents the real App Group container from opening in the widget integration tests. The default widget plan also includes manual widget UI installation cases; those are separate from the unit-only command above.

## Release preparation

See [release package](../../docs/release/README.md), [device acceptance log](../../docs/release/physical-device-qa.md), and [asset provenance/prompt](../../docs/release/asset-provenance.md). Set the actual team and published policy URL using a local copy of `Configuration/Release.example.xcconfig`. The public policy is linked in the in-app Privacy view when the HTTPS URL is configured.

```sh
xcodebuild -project PrayerFocus.xcodeproj -scheme PrayerFocus \
  -configuration Release -destination 'generic/platform=iOS' \
  -xcconfig Configuration/Release.local.xcconfig \
  -archivePath build/SalahSide.xcarchive archive
python3 scripts/release_preflight.py \
  build/SalahSide.xcarchive/Products/Applications/PrayerFocus.app \
  --team-id YOUR_REAL_TEAM_ID
```

`--structural-only` permits unsigned local/CI artifact inspection and never confirms distribution readiness. Even the signed-artifact mode does not prove Apple approval, published policy contents, live subscription configuration or device behavior.

## Remaining release gates

Registered-mat matching uses Vision feature-print revision 2 and an experimental maximum distance of 0.35. Synthetic image tests verify comparison wiring; they do not establish real-mat recognition accuracy or resistance to photographing a screen/printout. Calibrate and record same-mat versus different-mat results on real iPhones across framing, angles, patterned/plain mats and lighting before making accuracy claims. Simulator builds select supported CPU compute devices for Vision; physical devices use Vision's default compute selection. Vision can produce nearly identical prints for different images on iOS 26.5/27 simulators because of unsupported pixel-format rendering. CI therefore runs the comparison assertions against the production matcher in the required native macOS `PrayerFocusVision` scheme. The shared comparison test explicitly skips simulator execution and retains its assertions on physical iPhones. Storage, release guards and camera UI tests still run on the simulator; native macOS comparison does not establish iPhone matching accuracy. Mat profile backup exclusion is guidance to iOS, not an absolute guarantee.

Physical iPhone Screen Time behavior is **not validated**. Device Activity callbacks depend on device activity and are not exact wall-clock alarms. Monitor intervals shorter than Apple's 15-minute minimum are not registered. Qualified timetable review, actual notification delivery, sandbox subscription billing, real App Group sharing, distribution capability approval and accessibility/device acceptance all remain gates. Do not upload or describe this build as release-ready until those checks are recorded.
