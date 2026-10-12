import SwiftUI

struct MatSettingsSection: View {
    @Environment(RegisteredMatStore.self) private var matStore
    @Binding var capture: MatCapturePurpose?
    @Binding var isConfirmingRemoval: Bool
    @Binding var errorMessage: String?

    var body: some View {
        Section {
            if matStore.registrationID != nil {
                Toggle(
                    "Unlock with prayer mat",
                    isOn: Binding(
                        get: { matStore.isEnabled },
                        set: { enabled in perform { try matStore.setEnabled(enabled) } }
                    )
                )
                .tint(PrayerTheme.sage)
                .accessibilityIdentifier("mat.enabled")
                Button("Replace registered mat") { capture = .register(previousID: matStore.registrationID) }
                Button("Remove registered mat", role: .destructive) { isConfirmingRemoval = true }
            } else {
                Button("Register my prayer mat") { capture = .register(previousID: nil) }
                    .accessibilityIdentifier("mat.register")
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        } header: {
            Text("Prayer mat unlock · Optional")
        } footer: {
            Text(
                "Register your own mat to unlock with a fresh photo. Comparison happens on this iPhone. Manual unlock remains available."
            )
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
        } catch {
            errorMessage = "Your mat settings could not be changed. Please try again."
        }
    }
}
