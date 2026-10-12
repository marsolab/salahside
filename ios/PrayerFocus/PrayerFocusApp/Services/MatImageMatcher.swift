import Foundation
import ImageIO
import Vision

enum MatUnlockError: LocalizedError {
    case invalidImage
    case invalidReference
    case noRegistration
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: "This photo could not be compared. Retake it with the whole mat in good light."
        case .invalidReference: "Your saved mat is unavailable. Register it again in Settings."
        case .noRegistration: "Register your prayer mat first."
        case .saveFailed: "Your mat settings could not be saved. Please try again."
        }
    }
}

/// Actor isolation keeps Vision work away from the UI. Only encoded bytes cross actors.
actor MatImageMatcher {
    static let revision = VNGenerateImageFeaturePrintRequestRevision2
    // Experimental, deliberately conservative. Real-mat/device calibration is still required.
    private let maximumDistance: Float = 0.35

    func featurePrint(for image: Data) throws -> Data {
        let observation = try observation(for: image)
        return try NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
    }

    func matches(image: Data, reference: Data) throws -> Bool {
        let saved = try Self.decode(reference)
        let current = try observation(for: image)
        var distance: Float = .infinity
        try current.computeDistance(&distance, to: saved)
        return distance.isFinite && distance >= 0 && distance <= maximumDistance
    }

    nonisolated static func validate(_ data: Data) throws {
        _ = try decode(data)
    }

    private nonisolated static func decode(_ data: Data) throws -> VNFeaturePrintObservation {
        guard !data.isEmpty, data.count <= 65_536,
            let print = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data),
            print.requestRevision == revision, print.elementCount > 0
        else { throw MatUnlockError.invalidReference }
        return print
    }

    private func observation(for data: Data) throws -> VNFeaturePrintObservation {
        guard !data.isEmpty, data.count <= 20_000_000,
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetType(source) != nil,
            let image = CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1024,
                ] as CFDictionary),
            min(image.width, image.height) >= 160
        else { throw MatUnlockError.invalidImage }
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = Self.revision
        request.imageCropAndScaleOption = .scaleFit
        #if targetEnvironment(simulator)
            // Simulator inference must use an available CPU rather than device-only accelerators.
            let devices = try request.supportedComputeStageDevices
            for (stage, supported) in devices {
                if let cpu = supported.first(where: {
                    if case .cpu = $0 { return true }
                    return false
                }) {
                    request.setComputeDevice(cpu, for: stage)
                }
            }
        #endif
        try VNImageRequestHandler(cgImage: image).perform([request])
        guard let result = request.results?.first else { throw MatUnlockError.invalidImage }
        return result
    }

}
