import FamilyControls
import SwiftUI

struct FocusSettingsView: View {
    @Bindable var session: PrayerFocusSession
    @Environment(ScreenTimeService.self) private var screenTime
    @Environment(FocusConfiguration.self) private var configuration
    @Environment(RegisteredMatStore.self) private var matStore
    @Environment(\.dismiss) private var dismiss
    var isSetup = false
    var allowsPrayerActions = true

    @State private var isPickerPresented = false
    @State private var isConfirmingErase = false
    @State private var eraseError: String?
    @State private var matCapture: MatCapturePurpose?
    @State private var isConfirmingMatRemoval = false
    @State private var matError: String?

    var body: some View {
        @Bindable var screenTime = screenTime
        @Bindable var configuration = configuration

        NavigationStack {
            Form {
                if isSetup {
                    Section {
                        Text("Make space for salah, your way.")
                            .font(.title2.weight(.semibold))
                        Text(
                            "Choose your prayer settings and the apps you want to pause. You can change these later, pause focus, or unlock apps for any prayer."
                        )
                        Text(
                            "Next, choose a monthly or yearly membership. Eligible subscribers can start with 3 days free after confirming with Apple."
                        )
                        .foregroundStyle(PrayerTheme.secondaryInk)
                    }
                }

                Section {
                    Picker("City", selection: $configuration.city) {
                        ForEach(FocusConfiguration.cities, id: \.self) { city in
                            Text(city).tag(city)
                        }
                    }
                    .accessibilityIdentifier("setup.city")

                    Picker("Calculation method", selection: $configuration.calculationMethod) {
                        ForEach(FocusConfiguration.methods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                    .accessibilityIdentifier("setup.calculationMethod")

                    Picker("High-latitude rule", selection: $configuration.highLatitudeRule) {
                        ForEach(FocusConfiguration.highLatitudeRules, id: \.self) { Text($0).tag($0) }
                    }
                    Text(
                        "Recommended uses one seventh of the night for London, and the middle of the night for the other supported cities."
                    )
                    .font(.footnote).foregroundStyle(PrayerTheme.secondaryInk)

                    Toggle("Hanafi Asr time", isOn: $configuration.hanafiAsr)
                    Text(
                        configuration.hanafiAsr
                            ? "Asr uses the Hanafi shadow convention." : "Asr uses the standard shadow convention."
                    )
                    .font(.footnote)
                    .foregroundStyle(PrayerTheme.secondaryInk)

                    DisclosureGroup("Adjust prayer times") {
                        ForEach(Prayer.allCases) { prayer in
                            Stepper(
                                "\(prayer.displayName): \(configuration.adjustments[prayer.rawValue, default: 0]) min",
                                value: Binding(
                                    get: { configuration.adjustments[prayer.rawValue, default: 0] },
                                    set: { configuration.adjustments[prayer.rawValue] = $0 }),
                                in: -120...120)
                        }
                    }
                } header: {
                    Text("Prayer schedule")
                } footer: {
                    Text(
                        "Times are calculated on this device in your selected city’s time zone. Match the method, Asr convention and adjustments to your local mosque. For Umm al-Qura, adjust Isha by +30 minutes during Ramadan if your local timetable requires it."
                    )
                }

                if !isSetup && allowsPrayerActions {
                    Section {
                        NavigationLink {
                            DailyAffirmationView()
                        } label: {
                            Label("Daily affirmations", systemImage: "moon")
                        }
                        .accessibilityIdentifier("settings.dailyAffirmations")
                    }
                }

                Section {
                    LabeledContent("Permission", value: screenTime.authorizationLabel)

                    if !screenTime.isAuthorized {
                        Button("Allow Screen Time access") {
                            Task { await screenTime.requestAuthorization() }
                        }
                    }

                    Button {
                        isPickerPresented = true
                    } label: {
                        LabeledContent("Distracting apps", value: selectedItemsLabel)
                    }
                    .disabled(!screenTime.isAuthorized)

                    if let lastError = screenTime.lastError {
                        Text(lastError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Screen Time")
                } footer: {
                    Text(
                        "Choose the apps you want to pause during enabled prayers. Finish, already prayed, unlock, or pause focus to restore access."
                    )
                }

                if isSetup || allowsPrayerActions {
                    MatSettingsSection(
                        capture: $matCapture, isConfirmingRemoval: $isConfirmingMatRemoval, errorMessage: $matError)
                }

                Section("Focus for prayers") {
                    ForEach(Prayer.allCases) { prayer in
                        Toggle(
                            prayer.displayName,
                            isOn: focusBinding(for: prayer)
                        )
                        .tint(PrayerTheme.sage)
                        .accessibilityIdentifier("setup.prayer.\(prayer.rawValue)")
                    }
                }

                if !isSetup && allowsPrayerActions {
                    Section("Pause focus") {
                        if let until = screenTime.pauseUntil, until > Date() {
                            LabeledContent("Paused until", value: until.formatted(date: .omitted, time: .shortened))
                            Button("Resume focus") { screenTime.resumeFocus() }
                        } else {
                            Button("Pause for one hour") { screenTime.pauseForOneHour() }
                        }
                    }
                }

                Section {
                    Toggle("Prayer start notification", isOn: $configuration.notificationsEnabled)
                        .tint(PrayerTheme.sage)
                        .accessibilityIdentifier("setup.notifications")
                } header: {
                    Text("Notifications")
                } footer: {
                    Text(
                        "Requires notification permission in iOS Settings. Reminders are scheduled for the next seven days, within your membership period, and refreshed when you open SalahSide."
                    )
                }

                if allowsPrayerActions && !isSetup {
                    Section {
                        Button("Unlock current prayer") {
                            session.unlockWithoutCheckIn()
                            dismiss()
                        }
                    } footer: {
                        Text("Check-ins are self-reported and saved locally. They may be included in device backups.")
                    }
                }
                Section("Privacy") {
                    NavigationLink("Privacy policy") { MembershipPrivacyView() }
                    Button("Erase local data", role: .destructive) { isConfirmingErase = true }
                }
            }
            .confirmationDialog("Erase local data?", isPresented: $isConfirmingErase, titleVisibility: .visible) {
                Button("Erase settings and check-ins", role: .destructive) {
                    do {
                        try matStore.remove()
                    } catch {
                        eraseError = "Your registered mat could not be removed. Please try erasing again."
                        return
                    }
                    FocusRuntime().erase()
                    session.eraseLocalHistory()
                    session.focusEnabled = Dictionary(uniqueKeysWithValues: Prayer.allCases.map { ($0, true) })
                    screenTime.selection = FamilyActivitySelection()
                    screenTime.resumeFocus()
                    configuration.eraseLocalSetup()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "This deletes local prayer settings, app selections, check-ins and your registered mat, and unlocks selected apps. Your Apple subscription remains active. Existing device backups are not erased."
                )
            }
            .alert(
                "Local data was not erased",
                isPresented: Binding(get: { eraseError != nil }, set: { if !$0 { eraseError = nil } })
            ) {
                Button("OK") { eraseError = nil }
            } message: {
                Text(eraseError ?? "Please try again.")
            }
            .navigationTitle(isSetup ? "Set up SalahSide" : "Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isSetup {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSetup {
                    VStack(spacing: 8) {
                        Button("Continue to membership") { configuration.completeSetup() }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: PrayerTheme.controlHeight)
                            .background(PrayerTheme.sage, in: RoundedRectangle(cornerRadius: 16))
                            .buttonStyle(.plain)
                            .disabled(!configuration.canCompleteSetup)
                            .opacity(configuration.canCompleteSetup ? 1 : 0.5)
                            .accessibilityIdentifier("setup.continue")
                        Text("Your setup is saved. No payment is taken here.")
                            .font(.footnote)
                            .foregroundStyle(PrayerTheme.secondaryInk)
                    }
                    .padding(16)
                    .background(PrayerTheme.canvas)
                }
            }
            .familyActivityPicker(
                isPresented: $isPickerPresented,
                selection: $screenTime.selection
            )
        }
        .tint(PrayerTheme.sage)
        .sheet(item: $matCapture) { purpose in MatCaptureView(purpose: purpose, session: session) }
        .confirmationDialog(
            "Remove your registered mat?", isPresented: $isConfirmingMatRemoval, titleVisibility: .visible
        ) {
            Button("Remove mat", role: .destructive) {
                do {
                    try matStore.remove()
                    matError = nil
                } catch {
                    matError = "Your registered mat could not be removed. Please try again."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes its saved comparison fingerprint and turns off photo unlock.")
        }
    }

    private var selectedItemsLabel: String {
        let count = screenTime.selectedItemCount
        return count == 0 ? "None" : "\(count) selected"
    }

    private func focusBinding(for prayer: Prayer) -> Binding<Bool> {
        Binding(
            get: { session.isFocusEnabled(for: prayer) },
            set: { session.focusEnabled[prayer] = $0 }
        )
    }
}
