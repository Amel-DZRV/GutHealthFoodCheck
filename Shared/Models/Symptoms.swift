import SwiftUI

/// All symptoms are rated 0 (none) to 5 (worst).
enum SymptomScale {
    static let range = 0...5
}

/// Bristol Stool Scale. Types 3–4 are considered normal.
enum BristolType: Int, CaseIterable, Identifiable {
    case notRecorded = 0
    case type1, type2, type3, type4, type5, type6, type7

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .notRecorded: "Not recorded"
        case .type1: "1 · Separate hard lumps"
        case .type2: "2 · Lumpy, sausage-shaped"
        case .type3: "3 · Sausage with cracks"
        case .type4: "4 · Smooth and soft"
        case .type5: "5 · Soft blobs"
        case .type6: "6 · Mushy, fluffy pieces"
        case .type7: "7 · Watery, no solid pieces"
        }
    }

    var shortTitle: String { "Bristol \(rawValue)" }

    var isNormal: Bool { self == .type3 || self == .type4 }
}

enum OnsetTime: Int, CaseIterable, Identifiable {
    case unknown = 0
    case under30Minutes
    case under1Hour
    case oneToFourHours
    case fourToEightHours
    case nextDay

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .unknown: "Not sure / none"
        case .under30Minutes: "Within 30 min"
        case .under1Hour: "30–60 min"
        case .oneToFourHours: "1–4 hours"
        case .fourToEightHours: "4–8 hours"
        case .nextDay: "Next day"
        }
    }
}

/// How well a food seems to be tolerated, based on its logged reactions.
enum Tolerance {
    case untested
    case safe
    case caution
    case trigger

    init(averageSeverity: Double?) {
        switch averageSeverity {
        case nil: self = .untested
        case let value? where value < 1.5: self = .safe
        case let value? where value < 3: self = .caution
        default: self = .trigger
        }
    }

    var title: String {
        switch self {
        case .untested: "Not tested"
        case .safe: "Tolerated"
        case .caution: "Caution"
        case .trigger: "Trigger"
        }
    }

    var systemImage: String {
        switch self {
        case .untested: "circle.dashed"
        case .safe: "checkmark.circle.fill"
        case .caution: "exclamationmark.circle.fill"
        case .trigger: "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .untested: .secondary
        case .safe: .green
        case .caution: .orange
        case .trigger: .red
        }
    }
}

extension Color {
    /// Green → red for a 0–5 symptom score.
    static func forScore(_ score: Double) -> Color {
        switch score {
        case ..<1.5: .green
        case ..<3: .orange
        default: .red
        }
    }
}
