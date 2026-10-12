import UIKit
import Vision
import XCTest

@testable import PrayerFocus

@MainActor
final class RegisteredMatTests: XCTestCase {
    private nonisolated let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testRegistrationIsOptionalAndPersistsWithoutSavingPhoto() async throws {
        let store = RegisteredMatStore(directory: directory)
        XCTAssertFalse(store.isEnabled)
        XCTAssertNil(store.registrationID)
        let fingerprint = try await MatImageMatcher().featurePrint(for: imageData(patterned: true))
        try store.register(featurePrint: fingerprint)
        XCTAssertTrue(store.isEnabled)
        let restored = RegisteredMatStore(directory: directory)
        XCTAssertEqual(restored.registrationID, store.registrationID)
        XCTAssertEqual(restored.featurePrint, fingerprint)
        XCTAssertTrue(restored.isEnabled)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 1)
        let profileURL = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first)
        XCTAssertEqual(try profileURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        XCTAssertFalse(try Data(contentsOf: profileURL).starts(with: [0xFF, 0xD8]))
    }

    func testDisableRetainsReferenceAndRemoveClearsItAcrossRelaunch() async throws {
        let store = RegisteredMatStore(directory: directory)
        try store.register(featurePrint: await MatImageMatcher().featurePrint(for: imageData(patterned: true)))
        let id = store.registrationID
        try store.setEnabled(false)
        XCTAssertFalse(RegisteredMatStore(directory: directory).isEnabled)
        XCTAssertEqual(store.registrationID, id)
        try store.setEnabled(true)
        XCTAssertTrue(store.isEnabled)
        try store.remove()
        XCTAssertNil(store.registrationID)
        XCTAssertFalse(store.isEnabled)
        XCTAssertNil(RegisteredMatStore(directory: directory).featurePrint)
    }

    func testFailedWriteDoesNotActivateRegistration() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blockedDirectory = directory.appendingPathComponent("file")
        try Data([1]).write(to: blockedDirectory)
        let store = RegisteredMatStore(directory: blockedDirectory)
        let fingerprint = try await MatImageMatcher().featurePrint(for: imageData(patterned: true))
        XCTAssertThrowsError(try store.register(featurePrint: fingerprint))
        XCTAssertFalse(store.isEnabled)
        XCTAssertNil(store.registrationID)
    }

    func testReplacingReferenceInvalidatesOldRegistration() async throws {
        let store = RegisteredMatStore(directory: directory)
        let fingerprint = try await MatImageMatcher().featurePrint(for: imageData(patterned: true))
        try store.register(featurePrint: fingerprint)
        let id = store.registrationID
        try store.register(featurePrint: fingerprint)
        XCTAssertNotEqual(store.registrationID, id)
    }

    func testMalformedImageAndReferenceFailWithoutMatching() async throws {
        let matcher = MatImageMatcher()
        do {
            _ = try await matcher.featurePrint(for: Data([1, 2, 3]))
            XCTFail("Malformed image was accepted")
        } catch {}
        do {
            _ = try await matcher.matches(image: imageData(patterned: true), reference: Data([1]))
            XCTFail("Malformed reference was accepted")
        } catch {}
        XCTAssertThrowsError(try RegisteredMatStore(directory: directory).register(featurePrint: Data([1])))
    }

    func testVisionMatchesSameImageAndRejectsUnrelatedSyntheticScene() async throws {
        let matcher = MatImageMatcher()
        let image = imageData(patterned: true)
        let reference = try await matcher.featurePrint(for: image)
        let same = try await matcher.matches(image: image, reference: reference)
        let otherImage = imageData(patterned: false)
        for (name, data) in [("Synthetic pattern", image), ("Synthetic circle", otherImage)] {
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.jpeg")
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertNotEqual(image, otherImage)
        let other = try await matcher.matches(image: otherImage, reference: reference)
        let otherPrint = try await matcher.featurePrint(for: otherImage)
        let original = try XCTUnwrap(
            NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: reference))
        let different = try XCTUnwrap(
            NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: otherPrint))
        var distance: Float = 0
        try original.computeDistance(&distance, to: different)
        let normA = original.data.withUnsafeBytes { bytes in
            bytes.bindMemory(to: Float.self).reduce(0.0) { $0 + Double($1 * $1) }.squareRoot()
        }
        let normB = different.data.withUnsafeBytes { bytes in
            bytes.bindMemory(to: Float.self).reduce(0.0) { $0 + Double($1 * $1) }.squareRoot()
        }
        XCTAssertNotEqual(original.data, different.data, "Different scenes must have distinct fingerprints")
        XCTAssertTrue(same)
        XCTAssertFalse(other, "Different-scene distance: \(distance); norms: \(normA), \(normB)")
    }

    func testMatchedMatReleasesOnlyCapturedPrayerWithoutCompletion() throws {
        let config = FocusConfiguration()
        config.city = "Dubai"
        config.calculationMethod = "Dubai"
        let session = PrayerFocusSession()
        let now = Date(timeIntervalSince1970: 1_791_720_000)
        session.refresh(configuration: config, at: now)
        let eventID = try XCTUnwrap(session.currentEventID)
        var released: [String] = []
        session.onRelease = { released.append($0) }
        XCTAssertTrue(session.unlockForMatchedMat(eventID: eventID))
        XCTAssertEqual(session.phase, .unlocked)
        XCTAssertEqual(released, [eventID])
        XCTAssertFalse(session.unlockForMatchedMat(eventID: eventID))
        session.refresh(configuration: config, at: now.addingTimeInterval(86_400))
        XCTAssertFalse(session.unlockForMatchedMat(eventID: eventID))
        XCTAssertEqual(session.phase, .ready)
        XCTAssertEqual(released, [eventID])
    }

    func testCorruptAndUnsupportedSavedProfilesDoNotEnablePhotoUnlock() async throws {
        let store = RegisteredMatStore(directory: directory)
        let fingerprint = try await MatImageMatcher().featurePrint(for: imageData(patterned: true))
        try store.register(featurePrint: fingerprint)
        let file = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first)
        var profile = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        profile["version"] = 99
        try JSONSerialization.data(withJSONObject: profile).write(to: file)
        XCTAssertFalse(RegisteredMatStore(directory: directory).isEnabled)
        try Data([1, 2, 3]).write(to: file)
        XCTAssertNil(RegisteredMatStore(directory: directory).registrationID)
        try Data(repeating: 0, count: 100_001).write(to: file)
        XCTAssertNil(RegisteredMatStore(directory: directory).featurePrint)
        try store.remove()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testPhotoUnlockCannotOverwriteCompletionOrReleaseInvalidSchedule() throws {
        let config = FocusConfiguration()
        config.city = "Dubai"
        config.calculationMethod = "Dubai"
        let session = PrayerFocusSession()
        let now = Date(timeIntervalSince1970: 1_791_720_000)
        session.refresh(configuration: config, at: now)
        let id = try XCTUnwrap(session.currentEventID)
        session.markAlreadyPrayed()
        XCTAssertFalse(session.unlockForMatchedMat(eventID: id))
        XCTAssertEqual(session.phase, .checkedIn)
        let invalid = PrayerFocusSession()
        invalid.refresh(configuration: FocusConfiguration(), at: now)
        XCTAssertFalse(invalid.unlockForMatchedMat(eventID: id))
        XCTAssertTrue(invalid.releasedEventIDs.isEmpty)
    }

    private func imageData(patterned: Bool) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 384, height: 512))
        return renderer.jpegData(withCompressionQuality: 0.9) { context in
            if patterned {
                UIColor.darkGray.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 384, height: 512))
                for row in 0..<12 {
                    for col in 0..<8 {
                        ((row + col).isMultiple(of: 2) ? UIColor.orange : UIColor.blue).setFill()
                        context.fill(CGRect(x: 32 + col * 40, y: 16 + row * 40, width: 32, height: 32))
                    }
                }
            } else {
                UIColor.green.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 384, height: 512))
                UIColor.red.setFill()
                context.cgContext.fillEllipse(in: CGRect(x: 40, y: 140, width: 280, height: 240))
            }
        }
    }
}
