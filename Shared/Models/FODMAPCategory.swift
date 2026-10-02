import SwiftUI

/// FODMAP groups as used by the Monash University low-FODMAP diet,
/// plus buckets for safe foods and foods that are mixed or unknown.
enum FODMAPCategory: String, CaseIterable, Identifiable, Codable {
    case fructans
    case gos
    case lactose
    case fructose
    case sorbitol
    case mannitol
    case lowFODMAP
    case mixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fructans: "Fructans"
        case .gos: "GOS"
        case .lactose: "Lactose"
        case .fructose: "Excess Fructose"
        case .sorbitol: "Sorbitol"
        case .mannitol: "Mannitol"
        case .lowFODMAP: "Low FODMAP"
        case .mixed: "Mixed / Unsure"
        }
    }

    var subtitle: String {
        switch self {
        case .fructans: "Oligosaccharide · wheat, onion, garlic"
        case .gos: "Oligosaccharide · legumes, cashews"
        case .lactose: "Disaccharide · milk, yogurt, soft cheese"
        case .fructose: "Monosaccharide · apple, honey, mango"
        case .sorbitol: "Polyol · stone fruit, avocado"
        case .mannitol: "Polyol · mushrooms, cauliflower"
        case .lowFODMAP: "Generally well tolerated"
        case .mixed: "Several groups, or not sure yet"
        }
    }

    var systemImage: String {
        switch self {
        case .fructans: "leaf.fill"
        case .gos: "circle.hexagongrid.fill"
        case .lactose: "drop.fill"
        case .fructose: "sun.max.fill"
        case .sorbitol: "seal.fill"
        case .mannitol: "staroflife.fill"
        case .lowFODMAP: "checkmark.seal.fill"
        case .mixed: "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .fructans: .orange
        case .gos: .brown
        case .lactose: .blue
        case .fructose: .pink
        case .sorbitol: .purple
        case .mannitol: .indigo
        case .lowFODMAP: .green
        case .mixed: .gray
        }
    }
}

enum PortionUnit: String, CaseIterable, Identifiable, Codable {
    case grams = "g"
    case milliliters = "ml"

    var id: String { rawValue }
}
