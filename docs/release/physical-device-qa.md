# Physical iPhone acceptance log

Status: **not run**. Record device, iOS, signed version/build, tester, timestamp, selected test app and observed result for each row. Save a screen recording plus Device Activity diagnostics for scheduled shield/clear cases. Simulator tests do not fill this log.

| Case | Required observation | Result |
|---|---|---|
| Individual Screen Time permission | Approved, declined and revoked; app itself stays accessible | Pending |
| Shield return route | Open SalahSide on iOS 26.5+, manual return on earlier iOS | Pending |
| Selection | Apps, categories and websites respect the current picker selection | Pending |
| Enabled prayer | Selected targets shield when the event is delivered, app foreground/background/killed | Pending |
| Finish / Already prayed | Shield clears and exactly one local completion is stored | Pending |
| Unlock | Shield clears without a completion; repeated callbacks do not reapply it | Pending |
| Mat registration / privacy | Optional, initially off; camera requested on capture only; register/replace/remove/relaunch; no raw photo persisted or uploaded | Pending |
| Mat comparison | Same mat vs different mat across patterned/plain mats, light, framing, rotation and iPhone models; record distances and acceptance/rejection before calibrating the 0.35 threshold | Pending |
| Mat release / cancellation | Matching capture clears only the current shield without completion; mismatch, cancellation, changed event/registration and expired membership never photo-unlock | Pending |
| Camera denied / unavailable | Clear recovery and ordinary manual unlock; no Photos-library permission | Pending |
| Pause / Resume | Immediate clear, manual/timed resume, including reopening under 15 minutes before expiry; no false completion | Pending |
| Disabled next prayer | Previous restriction clears; next restriction does not start | Pending |
| Membership expiry | Foreground and closed-app expiry clear restrictions; no purchase required to escape | Pending |
| Restore / renewal / refund | Verified access updates app, monitor and installed widgets | Pending |
| Restart | Device restart preserves correct state and provides an escape path | Pending |
| Date / DST / city change | Existing monitors replaced, correct city-local date, previous Isha until Fajr | Pending |
| Error / stale data | Invalid or unavailable state clears restrictions and offers recovery | Pending |
| Notification denied / changed | Schedule remains usable; reminders do not exceed saved membership expiry | Pending |
| Offline reminders | Next seven days scheduled; opening refreshes the horizon | Pending |
| Widget families | Install all three, longest text, expiry, tint, deep link and restoration | Pending |
| Accessibility | VoiceOver, largest Dynamic Type, contrast and reduced motion | Pending |
| Erase local data | Immediate clear, setup shown again, local history/token/mat removal; deletion failure is surfaced; subscription persists | Pending |

Apple's Device Activity callbacks follow device activity and are not a precise wall-clock alarm. Verify observed behavior before making timing claims. Schedule registration failures must leave app-owned restrictions cleared.

Qualified schedule review is also pending: compare supported methods, Hanafi/standard Asr, high-latitude rules, Dubai summer/winter, London summer and DST dates, and local Umm al-Qura Ramadan adjustments with matching trusted timetables.
