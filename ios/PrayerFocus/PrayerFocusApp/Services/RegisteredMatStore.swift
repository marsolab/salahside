import Foundation
import Observation

@MainActor
@Observable
final class RegisteredMatStore {
    private struct Profile: Codable {
        var version = 1
        var revision = MatImageMatcher.revision
        var id = UUID()
        var isEnabled = true
        let featurePrint: Data
    }

    private var profile: Profile?
    private let directory: URL
    private var fileURL: URL { directory.appendingPathComponent("registered-mat.json") }

    var isEnabled: Bool { profile?.isEnabled == true }
    var registrationID: UUID? { profile?.id }
    var featurePrint: Data? { profile?.featurePrint }

    init(directory: URL? = nil) {
        self.directory =
            directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RegisteredMat", isDirectory: true)
        guard let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
            size <= 100_000, let data = try? Data(contentsOf: fileURL),
            let saved = try? JSONDecoder().decode(Profile.self, from: data),
            saved.version == 1, saved.revision == MatImageMatcher.revision,
            (try? MatImageMatcher.validate(saved.featurePrint)) != nil
        else { return }
        profile = saved
    }

    func register(featurePrint: Data) throws {
        try MatImageMatcher.validate(featurePrint)
        try save(Profile(featurePrint: featurePrint))
    }

    func setEnabled(_ enabled: Bool) throws {
        guard var next = profile else { throw MatUnlockError.noRegistration }
        next.isEnabled = enabled
        try save(next)
    }

    func remove() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        profile = nil
    }

    private func save(_ next: Profile) throws {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete])
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var protectedDirectory = directory
            try protectedDirectory.setResourceValues(values)
            try JSONEncoder().encode(next).write(to: fileURL, options: [.atomic, .completeFileProtection])
            var protectedFile = fileURL
            try protectedFile.setResourceValues(values)
            profile = next
        } catch {
            // Do not activate a partly saved replacement, or keep using an obsolete in-memory profile.
            profile = nil
            try? FileManager.default.removeItem(at: fileURL)
            throw MatUnlockError.saveFailed
        }
    }
}
