import Foundation
import SwiftData

enum ProgramRules {
    static let baselineDays = 7
    /// A test day is a reaction when bloating or gas is this far above the baseline average.
    static let reactionMargin = 2.0
    /// A settling day is calm when bloating and gas are within this of the baseline average.
    static let calmMargin = 1.0
    static let calmDaysNeeded = 2
    /// Baseline days scoring above this suggest the baseline diet itself bothers you.
    static let stableBaselineMax = 2
}

enum TestOutcome: Equatable {
    case pending
    case active(daysDone: Int)
    case tolerated
    case reaction(day: Int)
    case skipped

    var isFinished: Bool {
        switch self {
        case .tolerated, .reaction: true
        default: false
        }
    }
}

enum ProgramPhase {
    case waitingToStart(Date)
    case baseline(day: Int, target: Int)
    /// Enough baseline days are logged; waiting for you to start reintroduction.
    case baselineDone
    case testing(ReintroTest, day: Int)
    case settling(after: ReintroTest, calmDays: Int)
    case complete

    var kind: CheckInKind {
        switch self {
        case .waitingToStart, .baseline, .baselineDone: .baseline
        case .testing: .test
        case .settling: .settling
        case .complete: .free
        }
    }

    var test: ReintroTest? {
        switch self {
        case let .testing(test, _): test
        case let .settling(test, _): test
        default: nil
        }
    }

    var testDay: Int {
        if case let .testing(_, day) = self { return day }
        return 0
    }

    var isTesting: Bool {
        if case .testing = self { return true }
        return false
    }

    var badge: String {
        switch self {
        case let .waitingToStart(date):
            "STARTS \(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased())"
        case let .baseline(day, target):
            day > target ? "BASELINE · EXTRA DAY \(day - target)" : "BASELINE · DAY \(day)/\(target)"
        case .baselineDone: "BASELINE DONE"
        case let .testing(test, day): "TEST · DAY \(day)/\(test.durationDays)"
        case let .settling(_, calmDays): "SETTLING · \(calmDays)/\(ProgramRules.calmDaysNeeded) CALM"
        case .complete: "ALL DONE"
        }
    }

    var title: String {
        switch self {
        case .waitingToStart, .baseline: "Baseline"
        case .baselineDone: "Ready to test"
        case let .testing(test, _): test.name
        case .settling: "Plain lunch"
        case .complete: "Plan complete"
        }
    }

    var detail: String {
        switch self {
        case .waitingToStart:
            "Eat your standard meals and log bloating and gas every evening."
        case .baseline:
            "Standard breakfast, lunch and dinner. Log bloating and gas tonight."
        case .baselineDone:
            "Start reintroduction, or keep logging baseline days."
        case let .testing(test, _):
            "Add to lunch: \(test.instruction)."
        case let .settling(test, _):
            "Reacted to \(test.name). Baseline lunch until symptoms settle."
        case .complete:
            "Every food has been tested. See results in Plan."
        }
    }
}

struct BaselineStats {
    let days: Int
    let bloating: Double
    let gas: Double
    let maxBloating: Int
    let maxGas: Int

    var isStable: Bool {
        days >= ProgramRules.baselineDays
            && maxBloating <= ProgramRules.stableBaselineMax
            && maxGas <= ProgramRules.stableBaselineMax
    }
}

/// Derives the program state from what has been logged. Nothing here is stored,
/// so editing or deleting a check-in updates every result consistently.
struct ProgramEngine {
    let settings: ProgramSettings?
    let checkIns: [DailyCheckIn]
    let tests: [ReintroTest]

    init(settings: ProgramSettings?, checkIns: [DailyCheckIn], tests: [ReintroTest]) {
        self.settings = settings
        self.checkIns = checkIns.sorted { $0.day < $1.day }
        self.tests = tests.sorted { $0.order < $1.order }
    }

    // MARK: Baseline

    var baselineCheckIns: [DailyCheckIn] {
        checkIns.filter { $0.kind == .baseline }
    }

    /// Averages over the most recent baseline week.
    var baseline: BaselineStats? {
        let days = baselineCheckIns.suffix(ProgramRules.baselineDays)
        guard !days.isEmpty else { return nil }
        let count = Double(days.count)
        return BaselineStats(
            days: days.count,
            bloating: Double(days.map(\.bloating).reduce(0, +)) / count,
            gas: Double(days.map(\.gas).reduce(0, +)) / count,
            maxBloating: days.map(\.bloating).max() ?? 0,
            maxGas: days.map(\.gas).max() ?? 0
        )
    }

    func isReaction(bloating: Int, gas: Int) -> Bool {
        let base = baseline
        return Double(bloating) >= (base?.bloating ?? 0) + ProgramRules.reactionMargin
            || Double(gas) >= (base?.gas ?? 0) + ProgramRules.reactionMargin
    }

    func isCalm(_ checkIn: DailyCheckIn) -> Bool {
        let base = baseline
        return Double(checkIn.bloating) <= (base?.bloating ?? 0) + ProgramRules.calmMargin
            && Double(checkIn.gas) <= (base?.gas ?? 0) + ProgramRules.calmMargin
    }

    // MARK: Tests

    func testCheckIns(for test: ReintroTest) -> [DailyCheckIn] {
        checkIns.filter { $0.kind == .test && $0.test?.persistentModelID == test.persistentModelID }
    }

    func outcome(of test: ReintroTest) -> TestOutcome {
        let days = testCheckIns(for: test)
        if let index = days.firstIndex(where: { $0.stoppedTest || isReaction(bloating: $0.bloating, gas: $0.gas) }) {
            return .reaction(day: index + 1)
        }
        if days.count >= test.durationDays { return .tolerated }
        if test.isSkipped { return .skipped }
        return days.isEmpty ? .pending : .active(daysDone: days.count)
    }

    // MARK: Phase

    func checkIn(on date: Date) -> DailyCheckIn? {
        let day = Calendar.current.startOfDay(for: date)
        return checkIns.first { $0.day == day }
    }

    /// Today's phase: what a logged check-in counted as, otherwise what comes next.
    func phase(on date: Date) -> ProgramPhase {
        if let logged = checkIn(on: date) {
            return phase(for: logged)
        }
        return nextPhase(on: date)
    }

    /// The phase the next new check-in will be assigned to.
    func nextPhase(on date: Date) -> ProgramPhase {
        guard settings?.reintroStart != nil else {
            let logged = baselineCheckIns.count
            if logged == 0, let start = settings?.baselineStart,
               Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: start) {
                return .waitingToStart(start)
            }
            return logged >= ProgramRules.baselineDays
                ? .baselineDone
                : .baseline(day: logged + 1, target: ProgramRules.baselineDays)
        }

        // Finish a test that is under way.
        for test in tests {
            if case let .active(daysDone) = outcome(of: test) {
                return .testing(test, day: daysDone + 1)
            }
        }

        // After a reaction, wait for enough calm days in a row.
        if let lastTestDay = checkIns.last(where: { $0.kind == .test }),
           let lastTest = lastTestDay.test,
           case .reaction = outcome(of: lastTest) {
            let settlingDays = checkIns.filter { $0.kind == .settling && $0.day > lastTestDay.day }
            var calmStreak = 0
            for day in settlingDays.reversed() {
                guard isCalm(day) else { break }
                calmStreak += 1
            }
            if calmStreak < ProgramRules.calmDaysNeeded {
                return .settling(after: lastTest, calmDays: calmStreak)
            }
        }

        if let next = tests.first(where: { outcome(of: $0) == .pending }) {
            return .testing(next, day: 1)
        }
        return .complete
    }

    /// The phase a saved check-in was logged under.
    func phase(for checkIn: DailyCheckIn) -> ProgramPhase {
        switch checkIn.kind {
        case .baseline:
            let index = baselineCheckIns.firstIndex { $0.persistentModelID == checkIn.persistentModelID } ?? 0
            return .baseline(day: index + 1, target: ProgramRules.baselineDays)
        case .test:
            guard let test = checkIn.test else { return .complete }
            return .testing(test, day: checkIn.testDay)
        case .settling:
            guard let test = checkIn.test else { return .complete }
            return .settling(after: test, calmDays: 0)
        case .free:
            return .complete
        }
    }
}
