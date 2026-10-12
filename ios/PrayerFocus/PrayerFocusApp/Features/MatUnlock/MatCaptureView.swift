import AVFoundation
import SwiftUI

enum MatCapturePurpose: Identifiable {
    case register(previousID: UUID?)
    case unlock(eventID: String, registrationID: UUID, featurePrint: Data)

    var id: String {
        switch self {
        case .register(let id): "register-\(id?.uuidString ?? "new")"
        case .unlock(let eventID, let id, _): "unlock-\(eventID)-\(id.uuidString)"
        }
    }

    var isRegistration: Bool {
        if case .register = self { return true }
        return false
    }
}

struct MatCaptureView: View {
    let purpose: MatCapturePurpose
    let session: PrayerFocusSession
    @Environment(RegisteredMatStore.self) private var matStore
    @Environment(FocusConfiguration.self) private var configuration
    @Environment(MembershipStore.self) private var membership
    @Environment(\.dismiss) private var dismiss

    @State private var photo: Data?
    @State private var isCameraPresented = false
    @State private var isWorking = false
    @State private var message: String?
    @State private var needsCameraSettings = false
    @State private var operation: Task<Void, Never>?
    private let matcher = MatImageMatcher()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(purpose.isRegistration ? "Register your prayer mat" : "Photograph your registered mat")
                        .font(.title2.weight(.semibold))
                    Text("Unfold the mat and fill the photo with it. Take the photo from above in good light.")
                    if !purpose.isRegistration {
                        Text("Use a similar angle and distance to your registration photo.")
                            .foregroundStyle(PrayerTheme.secondaryInk)
                    }
                    if let photo, let image = UIImage(data: photo) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 340)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .accessibilityLabel("Your mat photo, ready to review")
                    }
                    if let message {
                        Text(message)
                            .foregroundStyle(PrayerTheme.secondaryInk)
                            .accessibilityIdentifier("mat.message")
                    }
                    if isWorking {
                        ProgressView("Processing on this iPhone…")
                    }
                    Button(photo == nil ? "Take photo" : "Retake photo", action: openCamera)
                        .buttonStyle(.bordered)
                        .disabled(isWorking)
                        .accessibilityIdentifier("mat.takePhoto")
                    if needsCameraSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open camera settings", destination: url)
                    }
                    if photo != nil {
                        Button(
                            purpose.isRegistration ? "Register this mat" : "Compare and unlock", action: processPhoto
                        )
                        .buttonStyle(.borderedProminent)
                        .disabled(isWorking)
                        .accessibilityIdentifier("mat.confirmPhoto")
                    }
                    Text(
                        "Photos are processed on this iPhone and discarded when you leave. Only a comparison fingerprint is saved for your registered mat."
                    )
                    .font(.footnote)
                    .foregroundStyle(PrayerTheme.secondaryInk)
                    Text(
                        "This is an optional unlock step. It does not verify prayer. Manual unlock is always available."
                    )
                    .font(.footnote)
                    .foregroundStyle(PrayerTheme.secondaryInk)
                }
                .padding(24)
            }
            .background(PrayerTheme.canvas.ignoresSafeArea())
            .navigationTitle(purpose.isRegistration ? "Prayer mat" : "Mat unlock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        operation?.cancel()
                        photo = nil
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $isCameraPresented) {
                MatCameraPicker { result in
                    isCameraPresented = false
                    guard let result else { return }
                    switch result {
                    case .success(let data):
                        photo = data
                        message = nil
                    case .failure(let error): message = error.localizedDescription
                    }
                }
                .ignoresSafeArea()
            }
            .onDisappear {
                if !isCameraPresented {
                    operation?.cancel()
                    photo = nil
                }
            }
        }
        .tint(PrayerTheme.sage)
    }

    private func openCamera() {
        message = nil
        needsCameraSettings = false
        guard UIImagePickerController.isSourceTypeAvailable(.camera),
            UIImagePickerController.isCameraDeviceAvailable(.rear)
        else {
            message = "A camera is unavailable on this device. You can still unlock manually."
            return
        }
        isWorking = true
        operation = Task { @MainActor in
            let allowed: Bool
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                allowed = await AVCaptureDevice.requestAccess(for: .video)
            } else {
                allowed = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
            }
            guard !Task.isCancelled else { return }
            isWorking = false
            if allowed {
                isCameraPresented = true
            } else {
                needsCameraSettings = true
                message = "Camera access is off. Allow it in iOS Settings or use manual unlock."
            }
        }
    }

    private func processPhoto() {
        guard let photo, !isWorking else { return }
        isWorking = true
        message = nil
        operation = Task { @MainActor in
            defer { isWorking = false }
            do {
                switch purpose {
                case .register(let previousID):
                    let fingerprint = try await matcher.featurePrint(for: photo)
                    guard !Task.isCancelled else { return }
                    guard matStore.registrationID == previousID else {
                        message = "Your registration changed. Close this screen and try again."
                        return
                    }
                    try matStore.register(featurePrint: fingerprint)
                case .unlock(let eventID, let registrationID, let fingerprint):
                    let matches = try await matcher.matches(image: photo, reference: fingerprint)
                    guard !Task.isCancelled else { return }
                    guard matStore.isEnabled, matStore.registrationID == registrationID else {
                        message = "Your mat settings changed. Close this screen and try again."
                        return
                    }
                    guard matches else {
                        message =
                            "This photo did not match your registered mat. Retake it with similar framing, or use manual unlock."
                        return
                    }
                    session.refresh(configuration: configuration)
                    guard membership.hasAccess, !membership.isRefreshingAccess,
                        session.unlockForMatchedMat(eventID: eventID)
                    else {
                        message =
                            "This prayer's focus changed while the camera was open. Close this screen to review the current prayer."
                        return
                    }
                }
                self.photo = nil
                dismiss()
            } catch {
                guard !Task.isCancelled else { return }
                message =
                    (error as? MatUnlockError)?.localizedDescription
                    ?? "The photo could not be processed on this device. Please try again or unlock manually."
            }
        }
    }
}
