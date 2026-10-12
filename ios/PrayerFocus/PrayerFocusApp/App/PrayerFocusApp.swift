import SwiftUI
import UIKit
import WidgetKit

@main
struct PrayerFocusApp: App {
    @State private var session: PrayerFocusSession
    @State private var screenTime: ScreenTimeService
    @State private var configuration: FocusConfiguration
    @State private var matStore: RegisteredMatStore
    @State private var membership = MembershipStore()
    @State private var affirmationDestination = AffirmationDestination()
    private let notifications = PrayerNotificationService()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let defaults: UserDefaults
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
                let suite = "com.marsolab.PrayerFocus.UITests"
                defaults = UserDefaults(suiteName: suite)!
                if ProcessInfo.processInfo.arguments.contains("-reset-setup") {
                    defaults.removePersistentDomain(forName: suite)
                }
            } else {
                defaults = .standard
            }
        #else
            defaults = .standard
        #endif
        _configuration = State(initialValue: FocusConfiguration(defaults: defaults))
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
                let store = RegisteredMatStore(
                    directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("RegisteredMatUITests", isDirectory: true))
                if ProcessInfo.processInfo.arguments.contains("-reset-setup") { try? store.remove() }
                _matStore = State(initialValue: store)
            } else {
                _matStore = State(initialValue: RegisteredMatStore())
            }
        #else
            _matStore = State(initialValue: RegisteredMatStore())
        #endif
        let session = PrayerFocusSession(defaults: defaults)
        session.onRelease = { FocusRuntime().release(eventID: $0) }
        _session = State(initialValue: session)
        _screenTime = State(initialValue: ScreenTimeService(defaults: defaults))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isAffirmationPreview {
                    NavigationStack {
                        DailyAffirmationView(previewAffirmation: DailyAffirmationCatalog.all[14])
                    }
                } else if isTodayPreview {
                    TodayView(session: session)
                } else if membership.hasCheckedEntitlements {
                    MembershipGateView(session: session)
                } else {
                    ProgressView()
                        .tint(PrayerTheme.sage)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PrayerTheme.canvas.ignoresSafeArea())
                }
            }
            .environment(screenTime)
            .environment(membership)
            .environment(configuration)
            .environment(matStore)
            .environment(affirmationDestination)
            .preferredColorScheme(.light)
            .onOpenURL { url in
                if affirmationDestination.receive(url) {
                    membership.beginAccessRefresh()
                    Task { await membership.refreshAccess() }
                }
            }
            .task {
                // The unit-test host must let SKTestSession configure StoreKit first.
                guard !isUnitTestHost else { return }
                #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-open-affirmation") {
                        affirmationDestination.receive(URL(string: "prayerfocus://daily-affirmation")!)
                    }
                #endif
                await membership.prepare()
                await refreshPrayerSchedule()
                await membership.observeTransactions()
            }
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
                if configuration.canCompleteSetup { session.refresh(configuration: configuration) }
                if !isUnitTestHost && !ProcessInfo.processInfo.arguments.contains("-ui-testing") {
                    FocusRuntime().applyCurrent()
                }
            }
            .task(
                id:
                    "\(configuration.city)|\(configuration.calculationMethod)|\(configuration.highLatitudeRule)|\(configuration.hanafiAsr)|\(configuration.adjustments.sorted(by: { $0.key < $1.key }))|\(configuration.notificationsEnabled)|\(screenTime.authorizationLabel)|\(membership.hasAccess)|\(configuration.hasCompletedSetup)|\(session.focusEnabled.sorted(by: { $0.key.rawValue < $1.key.rawValue }))"
            ) {
                await refreshPrayerSchedule()
            }
            .onChange(of: screenTime.selection) { _, _ in
                Task { await refreshPrayerSchedule() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && !isUnitTestHost {
                    membership.beginAccessRefresh()
                    Task {
                        await membership.refreshAccess()
                        await refreshPrayerSchedule()
                    }
                    WidgetCenter.shared.reloadTimelines(ofKind: WidgetMembershipStore.widgetKind)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) {
                _ in
                guard !isUnitTestHost else { return }
                membership.beginAccessRefresh()
                Task {
                    await membership.refreshAccess()
                    await refreshPrayerSchedule()
                }
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetMembershipStore.widgetKind)
            }
        }
    }

    private func refreshPrayerSchedule() async {
        session.refresh(configuration: configuration)
        guard !isUnitTestHost else { return }
        #if DEBUG
            guard !ProcessInfo.processInfo.arguments.contains("-ui-testing") else { return }
        #endif
        if configuration.hasCompletedSetup && configuration.canCompleteSetup {
            screenTime.updateFocus(configuration: configuration, session: session)
        } else {
            FocusRuntime().erase()
        }
        await notifications.update(configuration: configuration, membership: membership.verifiedMembership)
    }

    private var isUnitTestHost: Bool {
        #if DEBUG
            NSClassFromString("XCTestCase") != nil
        #else
            false
        #endif
    }

    private var isTodayPreview: Bool {
        #if DEBUG
            ProcessInfo.processInfo.arguments.contains("-preview-today")
        #else
            false
        #endif
    }

    private var isAffirmationPreview: Bool {
        #if DEBUG
            ProcessInfo.processInfo.arguments.contains("-preview-affirmation")
        #else
            false
        #endif
    }
}
