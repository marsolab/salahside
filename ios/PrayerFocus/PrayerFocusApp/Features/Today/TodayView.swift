import SwiftUI

struct TodayView: View {
    @Bindable var session: PrayerFocusSession
    @Environment(ScreenTimeService.self) private var screenTime
    @Environment(RegisteredMatStore.self) private var matStore
    var showSettings: (() -> Void)?

    @State private var isShowingSettings = false
    @State private var isConfirmingUnlock = false
    @State private var matCapture: MatCapturePurpose?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    PrayerHeroView(
                        prayer: session.currentPrayer,
                        phase: session.phase,
                        selectedItemCount: screenTime.selectedItemCount,
                        isAuthorized: screenTime.isAuthorized,
                        focusNotice: screenTime.lastError
                            ?? (screenTime.pauseUntil.map { $0 > Date() ? "Focus is paused." : nil } ?? nil),
                        prayerTime: session.currentEntry.flatMap { session.schedule?.formattedTime($0.date) },
                        isPrayerTime: session.isPrayerTime,
                        topSafeAreaInset: geometry.safeAreaInsets.top,
                        settingsAction: {
                            if let showSettings {
                                showSettings()
                            } else {
                                isShowingSettings = true
                            }
                        }
                    )

                    VStack(spacing: 12) {
                        Button(action: session.performPrimaryAction) {
                            HStack {
                                Spacer()
                                Text(session.primaryActionTitle)
                                    .font(.headline)
                                Spacer()
                                Image(
                                    systemName: session.phase == .inProgress
                                        ? "checkmark" : "arrow.right"
                                )
                                .font(.system(size: 18, weight: .semibold))
                            }
                            .padding(.horizontal, 20)
                            .frame(minHeight: PrayerTheme.controlHeight)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(PrayerTheme.sage)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .opacity(session.canPerformPrimaryAction ? 1 : 0.55)
                        .disabled(!session.canPerformPrimaryAction)

                        if session.isPrayerTime && !session.hasScheduleError && session.phase != .checkedIn {
                            Button("Already prayed", action: session.markAlreadyPrayed)
                                .font(.headline)
                                .foregroundStyle(PrayerTheme.sage)
                                .frame(maxWidth: .infinity, minHeight: PrayerTheme.controlHeight)
                                .background(PrayerTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(PrayerTheme.sage.opacity(0.65), lineWidth: 1)
                                }
                        }

                        if session.isPrayerTime && session.phase != .checkedIn && session.phase != .unlocked {
                            if matStore.isEnabled, let id = matStore.registrationID,
                                let fingerprint = matStore.featurePrint,
                                let eventID = session.currentEventID, !session.hasScheduleError,
                                !session.releasedEventIDs.contains(eventID)
                            {
                                Button {
                                    matCapture = .unlock(
                                        eventID: eventID, registrationID: id, featurePrint: fingerprint)
                                } label: {
                                    Label("Unlock with prayer mat", systemImage: "camera")
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(PrayerTheme.sage)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .accessibilityIdentifier("today.matUnlock")
                            }
                            Button("Unlock for this prayer") {
                                isConfirmingUnlock = true
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(PrayerTheme.secondaryInk)
                            .frame(minHeight: 44)
                        }
                    }
                    .padding(.horizontal, PrayerTheme.pageMargin)
                    .padding(.top, 42)

                    if session.hasScheduleError {
                        Text(
                            "Prayer times are unavailable. Review your city, calculation method and adjustments in Settings."
                        )
                        .font(.callout)
                        .foregroundStyle(PrayerTheme.secondaryInk)
                        .padding(.horizontal, PrayerTheme.pageMargin)
                    }
                    PrayerScheduleView(session: session)
                        .padding(.horizontal, PrayerTheme.pageMargin)
                        .padding(.top, 34)
                        .padding(.bottom, 36)
                }
            }
            .contentMargins(.top, 0, for: .scrollContent)
            .ignoresSafeArea(.container, edges: .top)
            .scrollIndicators(.hidden)
        }
        .background(PrayerTheme.canvas.ignoresSafeArea())
        .sheet(isPresented: $isShowingSettings) {
            FocusSettingsView(session: session)
                .environment(screenTime)
        }
        .sheet(item: $matCapture) { purpose in MatCaptureView(purpose: purpose, session: session) }
        .confirmationDialog(
            "Unlock selected apps for this prayer?",
            isPresented: $isConfirmingUnlock,
            titleVisibility: .visible
        ) {
            Button("Unlock without check-in", role: .destructive) {
                session.unlockWithoutCheckIn()
            }
            Button("Keep focus", role: .cancel) {}
        } message: {
            Text("This does not record the prayer as completed.")
        }
    }
}

#Preview {
    TodayView(session: PrayerFocusSession())
        .environment(ScreenTimeService())
        .environment(FocusConfiguration())
        .environment(MembershipStore())
        .environment(
            RegisteredMatStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("MatPreview")))
}
