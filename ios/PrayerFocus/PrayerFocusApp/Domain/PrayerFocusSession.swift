import Foundation
import Observation

@MainActor
@Observable
final class PrayerFocusSession {
    private(set) var currentPrayer: Prayer
    private(set) var phase: PrayerSessionPhase
    private(set) var schedule: PrayerSchedule?
    private(set) var currentEntry: PrayerScheduleEntry?
    private(set) var hasScheduleError = false
    private(set) var isPrayerTime = true
    private(set) var currentEventID: String?
    private(set) var releasedEventIDs: Set<String>
    @ObservationIgnored var onRelease: ((String) -> Void)?
    private var recordedPhases: [String: String]
    var focusEnabled: [Prayer: Bool] {
        didSet {
            defaults?.set(
                Dictionary(uniqueKeysWithValues: focusEnabled.map { ($0.key.rawValue, $0.value) }),
                forKey: "focus.enabledPrayers"
            )
        }
    }
    private let defaults: UserDefaults?

    init(
        currentPrayer: Prayer = .dhuhr,
        phase: PrayerSessionPhase = .ready,
        focusEnabled: [Prayer: Bool]? = nil,
        defaults: UserDefaults? = nil
    ) {
        self.currentPrayer = currentPrayer
        self.phase = phase
        self.defaults = defaults
        let history = defaults?.dictionary(forKey: "focus.checkIns.v1") as? [String: String] ?? [:]
        recordedPhases = history
        releasedEventIDs = Set(defaults?.stringArray(forKey: "focus.releasedEvents.v1") ?? [])
            .union(
                history.filter {
                    $0.value == PrayerSessionPhase.checkedIn.rawValue
                        || $0.value == PrayerSessionPhase.unlocked.rawValue
                }.keys)
        let savedFocus = defaults?.dictionary(forKey: "focus.enabledPrayers") as? [String: Bool]
        self.focusEnabled =
            focusEnabled
            ?? Dictionary(
                uniqueKeysWithValues: Prayer.allCases.map { ($0, savedFocus?[$0.rawValue] ?? true) }
            )
    }

    var primaryActionTitle: String {
        switch phase {
        case .ready: "Start prayer"
        case .inProgress: "Finish prayer"
        case .checkedIn: "Prayer checked in"
        case .unlocked: "Start prayer"
        }
    }

    var canPerformPrimaryAction: Bool {
        isPrayerTime && !hasScheduleError && phase != .checkedIn
    }

    func performPrimaryAction() {
        guard canPerformPrimaryAction else { return }
        switch phase {
        case .ready, .unlocked:
            phase = .inProgress
        case .inProgress:
            phase = .checkedIn
        case .checkedIn:
            break
        }
        savePhase()
    }

    func markAlreadyPrayed() {
        guard isPrayerTime && !hasScheduleError else { return }
        phase = .checkedIn
        savePhase()
    }

    func unlockWithoutCheckIn() {
        phase = .unlocked
        savePhase()
    }

    @discardableResult
    func unlockForMatchedMat(eventID: String) -> Bool {
        guard currentEventID == eventID, isPrayerTime, !hasScheduleError,
            phase != .checkedIn, !releasedEventIDs.contains(eventID)
        else { return false }
        unlockWithoutCheckIn()
        return true
    }

    func reset(for prayer: Prayer) {
        currentPrayer = prayer
        phase = .ready
    }

    func isFocusEnabled(for prayer: Prayer) -> Bool {
        focusEnabled[prayer, default: true]
    }

    func refresh(configuration: FocusConfiguration, at date: Date = Date()) {
        schedule = PrayerScheduleCalculator.calculate(
            city: configuration.city, method: configuration.calculationMethod,
            hanafiAsr: configuration.hanafiAsr, highLatitudeRule: configuration.highLatitudeRule,
            adjustments: configuration.adjustments, on: date)
        hasScheduleError = schedule == nil
        var previousEntry: PrayerScheduleEntry?
        if let schedule, schedule.current(at: date) == nil, let zone = TimeZone(identifier: schedule.timeZoneID) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            if let previousDay = calendar.date(byAdding: .day, value: -1, to: date) {
                previousEntry =
                    PrayerScheduleCalculator.calculate(
                        city: configuration.city, method: configuration.calculationMethod,
                        hanafiAsr: configuration.hanafiAsr, highLatitudeRule: configuration.highLatitudeRule,
                        adjustments: configuration.adjustments, on: previousDay)?.entries.last
            }
        }
        guard let schedule, let entry = schedule.current(at: date) ?? previousEntry ?? schedule.entries.first else {
            isPrayerTime = false
            currentEventID = nil
            currentEntry = nil
            return
        }
        currentEntry = entry
        isPrayerTime = entry.date <= date
        if entry.id != currentEventID {
            currentPrayer = entry.prayer
            currentEventID = entry.id
            phase = recordedPhases[entry.id].flatMap(PrayerSessionPhase.init(rawValue:)) ?? .ready
        }
    }

    func recordedPhase(for prayer: Prayer) -> PrayerSessionPhase? {
        guard let entry = schedule?.entries.first(where: { $0.prayer == prayer }) else { return nil }
        return recordedPhases[entry.id].flatMap(PrayerSessionPhase.init(rawValue:))
    }

    func eraseLocalHistory() {
        recordedPhases = [:]
        releasedEventIDs = []
        phase = .ready
        currentEventID = nil
        defaults?.removeObject(forKey: "focus.checkIns.v1")
        defaults?.removeObject(forKey: "focus.releasedEvents.v1")
    }

    private func savePhase() {
        guard let currentEventID else { return }
        recordedPhases[currentEventID] = phase.rawValue
        if phase == .checkedIn || phase == .unlocked {
            releasedEventIDs.insert(currentEventID)
            releasedEventIDs = Set(releasedEventIDs.sorted().suffix(90))
            defaults?.set(Array(releasedEventIDs), forKey: "focus.releasedEvents.v1")
            onRelease?(currentEventID)
        }
        // Bound local history without inferring completion for unrecorded prayers.
        for key in recordedPhases.keys.sorted().dropLast(90) {
            recordedPhases.removeValue(forKey: key)
        }
        defaults?.set(recordedPhases, forKey: "focus.checkIns.v1")
    }
}
