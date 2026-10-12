import SwiftUI
import UIKit

struct MatCameraPicker: UIViewControllerRepresentable {
    let onCapture: (Result<Data, MatUnlockError>?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Result<Data, MatUnlockError>?) -> Void

        init(onCapture: @escaping (Result<Data, MatUnlockError>?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCapture(nil) }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage, image.size.width > 0, image.size.height > 0 else {
                onCapture(.failure(.invalidImage))
                return
            }
            // Normalize orientation and bound memory. No Photos write or file persistence.
            let scale = min(1, 1280 / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let data = UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.9) { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            onCapture(.success(data))
        }
    }
}
