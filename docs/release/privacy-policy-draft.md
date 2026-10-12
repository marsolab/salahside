# SalahSide privacy policy — publication draft

Effective date: [publication date]. Publisher: [legal publisher name]. Contact: [support email]. Replace these fields and publish at an accessible HTTPS URL before distribution.

SalahSide does not require an account. The current iPhone app has no application backend, advertising SDK, behavioral analytics SDK or cloud-sync service.

## Information stored locally

The app saves your manually selected city, calculation method, prayer conventions and adjustments, notification preference, focus switches, self-reported prayer actions, temporary focus pause and opaque Apple Screen Time selection tokens. It uses bundled city coordinates to calculate prayer times; it does not request GPS permission or send your selected city to a server. Prayer history is bounded to 90 event records.

The app shares the minimum focus configuration, schedule, release/pause state and opaque selection tokens with its Screen Time extension through its Apple App Group. It shares a recognized subscription product identifier, verification time and expiration time with extensions so access can stop when the saved membership expires. Those extensions run on your device. No selected app identities or app-usage reports are uploaded by SalahSide.

## Optional prayer mat unlock

If you choose to register a prayer mat, the app requests camera permission when you take a photo. Registration and subsequent comparisons use Apple's Vision framework on your iPhone. SalahSide does not save the captured photographs, add them to your photo library, or upload photographs or comparison fingerprints. Captures are kept in memory for review and processing and discarded when you leave the capture flow.

The app stores a comparison fingerprint, registration identifier and enabled setting in protected app-private storage. The fingerprint is not shared with widgets or Screen Time extensions. This optional feature compares your chosen reference object; it does not verify worship or establish that the image contains a physical prayer mat. Manual unlock remains available. You can disable photo unlock, replace or remove the registration, or erase local data in Settings.

The app marks the mat profile as excluded from backups. This is guidance to iOS, not a guarantee that the profile can never appear in any backup or restored device.

## Apple services and payments

Apple processes purchases, subscription renewals and restoration through StoreKit. SalahSide receives verified subscription information needed to decide access, and does not receive your payment-card details. Apple's own services, diagnostics and account settings are governed by Apple's policies.

## Permissions

Screen Time access, notification permission and camera permission are optional. Without Screen Time permission, prayer times and check-ins still work after membership verification. Without camera permission, ordinary unlock remains available. You can change focus switches, unlock a prayer, pause focus and manage permissions in iOS Settings. Prayer check-ins are voluntary and self-reported; the app does not verify worship.

## Storage, backup and deletion

Settings, check-ins and selection tokens are stored locally. iOS device/iCloud backups may include local application data, subject to your Apple backup settings. The app does not promise that local data is excluded from all backups.

Settings → Erase local data removes the app's local prayer settings, app selection, check-in history and registered mat and clears its focus restrictions. It does not cancel your Apple subscription or delete existing device backups. Manage subscriptions through your Apple account and backups through Apple's settings.

## Website and support correspondence

The public page source is `front/src/pages/privacy.astro`; keep the final published policy synchronized with that source. The website has no analytics scripts, advertising trackers, accounts or contact form. Its host may process routine IP address, browser and request information to deliver and secure pages. Support email includes the sender address, message and voluntary attachments, used to respond and retained as needed for support or applicable obligations. Confirm the selected hosting and email providers before publication.

## Contact and changes

For privacy or support requests, contact [support email]. We will update this policy when the app's data practices change and show the effective date on the published page.
