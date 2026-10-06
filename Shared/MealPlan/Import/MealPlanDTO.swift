import Foundation

/// Mirrors the parts of `meal-plan.json` the importer uses. Unknown keys are ignored.
struct MealPlanDTO: Decodable {
    var targets: [String: TargetsDTO]
    var ingredients: [IngredientDTO]
    var recipes: RecipesDTO?
    var meals: [MealDTO]
    var plans: PlansDTO

    struct TargetsDTO: Decodable {
        var kcal: Double
        var proteinG: Double?
        var proteinGMin: Double?
        var proteinGMax: Double?

        enum CodingKeys: String, CodingKey {
            case kcal
            case proteinG = "protein_g"
            case proteinGMin = "protein_g_min"
            case proteinGMax = "protein_g_max"
        }
    }

    struct IngredientDTO: Decodable {
        var id: String
        var name: String
        var unit: String
        var aisle: String
        var macroBasis: String
        var kcal: Double
        var proteinG: Double
        var carbsG: Double
        var fatG: Double
        var fibreG: Double
        var cookedToDryRatio: Double?
        var note: String?
        var labelCheck: Bool?

        enum CodingKeys: String, CodingKey {
            case id, name, unit, aisle, kcal, note
            case macroBasis = "macro_basis"
            case proteinG = "protein_g"
            case carbsG = "carbs_g"
            case fatG = "fat_g"
            case fibreG = "fibre_g"
            case cookedToDryRatio = "cooked_to_dry_ratio"
            case labelCheck = "label_check"
        }
    }

    struct RecipesDTO: Decodable {
        var gfBreadSlice: BreadSliceDTO?
        var gfBreadLoaf: BreadLoafDTO?

        enum CodingKeys: String, CodingKey {
            case gfBreadSlice = "gf_bread_slice"
            case gfBreadLoaf = "gf_bread_loaf"
        }
    }

    struct BreadSliceDTO: Decodable {
        var perLoafFraction: Double?
        var kcal: Double
        var proteinG: Double
        var carbsG: Double
        var fatG: Double
        var fibreG: Double

        enum CodingKeys: String, CodingKey {
            case kcal
            case perLoafFraction = "per_loaf_fraction"
            case proteinG = "protein_g"
            case carbsG = "carbs_g"
            case fatG = "fat_g"
            case fibreG = "fibre_g"
        }
    }

    struct BreadLoafDTO: Decodable {
        var perLoaf: [LoafItemDTO]

        enum CodingKeys: String, CodingKey {
            case perLoaf = "per_loaf"
        }
    }

    struct LoafItemDTO: Decodable {
        var ingredient: String
        var amount: Double
    }

    struct MealDTO: Decodable {
        var id: String
        var person: String
        var slot: String
        var name: String
        var notes: String?
        var items: [MealItemDTO]
    }

    struct MealItemDTO: Decodable {
        var ingredient: String
        var amount: Double
        var unit: String
        var component: String?
        var state: String?
        var note: String?
    }

    struct PlansDTO: Decodable {
        var amel: AmelPlanDTO?
        var nina: NinaPlanDTO?
    }

    struct AmelPlanDTO: Decodable {
        var days: [AmelDayDTO]
    }

    struct AmelDayDTO: Decodable {
        var day: String
        var training: String?
        var meals: [String]
    }

    struct NinaPlanDTO: Decodable {
        var weeks: [NinaWeekDTO]
    }

    struct NinaWeekDTO: Decodable {
        var days: [NinaDayDTO]
    }

    struct NinaDayDTO: Decodable {
        var day: String
        var meals: [String]
    }
}
