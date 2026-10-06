import Foundation

/// Who is using this phone. Amel gets the gut program plus the meal plan, Nina only the meal plan.
enum Profile: String, CaseIterable, Identifiable {
    case amel, nina

    var id: String { rawValue }
    var displayName: String { self == .amel ? "Amel" : "Nina" }
    var hasGutProgram: Bool { self == .amel }
    static let storageKey = "profile"   // @AppStorage key; empty string = not chosen yet
}
