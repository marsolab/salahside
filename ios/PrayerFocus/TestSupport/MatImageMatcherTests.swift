import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision
import XCTest

#if os(iOS)
    @testable import PrayerFocus
#endif

@MainActor
final class MatImageMatcherTests: XCTestCase {
    func testVisionMatchesSameImageAndRejectsUnrelatedSyntheticScene() async throws {
        #if targetEnvironment(simulator)
            // Apple's Vision SDK documents inaccurate simulator pixel-format rendering.
            // These same assertions run in the required PrayerFocusVision macOS CI step
            // and remain enabled when this test target runs on a physical iPhone.
            throw XCTSkip("Vision image comparison requires native execution; run the PrayerFocusVision macOS scheme.")
        #else
            let matcher = MatImageMatcher()
            let image = try imageData(patterned: true)
            let reference = try await matcher.featurePrint(for: image)
            let same = try await matcher.matches(image: image, reference: reference)
            let otherImage = try imageData(patterned: false)
            XCTAssertNotEqual(image, otherImage)
            let other = try await matcher.matches(image: otherImage, reference: reference)
            let otherPrint = try await matcher.featurePrint(for: otherImage)
            let original = try XCTUnwrap(
                NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: reference))
            let different = try XCTUnwrap(
                NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: otherPrint))
            var distance: Float = 0
            try original.computeDistance(&distance, to: different)
            XCTAssertNotEqual(original.data, different.data, "Different scenes must have distinct fingerprints")
            XCTAssertTrue(same)
            XCTAssertFalse(other, "Different-scene distance: \(distance)")
        #endif
    }

    // Core Graphics fixtures are shared by the macOS and physical-iPhone test targets.
    private func imageData(patterned: Bool) throws -> Data {
        let context = try XCTUnwrap(
            CGContext(
                data: nil, width: 384, height: 512, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        if patterned {
            context.setFillColor(CGColor(gray: 0.33, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 384, height: 512))
            for row in 0..<12 {
                for col in 0..<8 {
                    context.setFillColor(
                        (row + col).isMultiple(of: 2)
                            ? CGColor(red: 1, green: 0.5, blue: 0, alpha: 1)
                            : CGColor(red: 0, green: 0, blue: 1, alpha: 1))
                    context.fill(CGRect(x: 32 + col * 40, y: 16 + row * 40, width: 32, height: 32))
                }
            }
        } else {
            context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 384, height: 512))
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fillEllipse(in: CGRect(x: 40, y: 140, width: 280, height: 240))
        }
        let image = try XCTUnwrap(context.makeImage())
        let data = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(
            destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
