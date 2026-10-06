# Implementation plan: meal plan in GutHealthFoodCheck

This plan adds the two-profile meal plan to the existing `GutHealthFoodCheck` repo. It is written so that a smaller model, such as Sonnet in Claude Code, can carry out **one task per session** without having to design anything.

Where this plan and `product_document.md` disagree, **this plan wins**. In particular, the import format is the real `meal-plan.json`, not the format sketched in the product document.

---

## 0. How to use this plan

**Per session:**
1. Start a fresh session in the repo root.
2. Paste the prompt below, filling in the task number.
3. Review the diff, build, run, and commit before starting the next task.

**Prompt template:**

```
You are implementing Task <N> from docs/implementation_plan.md in this repo.
Read these first, in order: docs/implementation_plan.md (sections 1–3 and Task <N> only),
then every file listed under "Read first" in Task <N>.
Rules:
- Do only Task <N>. Do not refactor, rename or reformat anything outside its file list.
- Follow the code conventions in section 2 exactly.
- When you finish, run the build command from section 2 and fix every error.
- Then list each acceptance check of Task <N> and say how you verified it.
If something in the task is ambiguous, stop and ask me instead of guessing.
```

**One-time setup (Amel, by hand, before Task 1):**
1. Copy `implementation_plan.md` and `product_document.md` into `docs/` in the repo.
2. Copy `meal-plan.json` into `docs/` as well. It's the reference data for the import format.
3. In Xcode, add a unit test target: *File → New → Target → Unit Testing Bundle*, named `GutHealthFoodCheckTests`, with host application `GutHealthFoodCheck`. Run it once with ⌘U to confirm it works.
4. Create `GutHealthFoodCheckTests/Fixtures/` and copy `meal-plan.json` into it.

---

## 1. Context the model must know

**Repo facts**
- The stack is SwiftUI, SwiftData and WidgetKit, iOS 17.0, Swift 5.
- The project uses **synchronized folders**: new files placed in existing folders are added to the build automatically. **Never edit `project.pbxproj`.**
- Files in `Shared/` are compiled into **both** the app and the widget extension, so code there must not import UIKit or use app-only types. Put views in `GutHealthFoodCheck/Views/`.
- `Shared/Program/SharedStore.swift` holds the SwiftData `Schema`. Every new `@Model` must be added to `SharedStore.schema`, or it will crash at runtime.
- Existing gut-program code stays as it is unless a task says otherwise: `ProgramEngine`, `ProgramActions`, `DailyCheckIn`, `ReintroTest`, `ProgramSettings`, `ReminderScheduler`, and the Plan and Foods tabs.
- `meal-plan.json` structure (read the file itself for details):
  - `targets.<person>` holds `kcal`, and either `protein_g` or `protein_g_min` + `protein_g_max`.
  - `ingredients[]` is the catalog: `id`, `name`, `unit` (`g`, `ml`, `pcs`), `aisle`, and `macro_basis` (`per_100g`, `per_100ml`, `per_piece`), plus `kcal`, `protein_g`, `carbs_g`, `fat_g`, `fibre_g` and the optional fields `cooked_to_dry_ratio`, `note` and `label_check`.
  - `recipes.gf_bread_slice` is a per-piece pseudo-ingredient with the same five macros. `recipes.gf_bread_loaf.per_loaf[]` lists the loaf's ingredients, and one slice is 1/10 of the loaf.
  - `meals[]` entries have `id`, `person`, `slot`, `name`, optional `notes`, and `items[]`. Each item has `ingredient` (a catalog id or `gf_bread_slice`), `amount`, `unit`, `component`, and optional `state` and `note`. Meal-level macro fields in the file are **ignored**; the app computes them.
  - `plans.amel.days[]` holds 7 entries with `day` (`mon` to `sun`), `training`, and `meals[]` (meal ids).
  - `plans.nina.weeks[]` holds 2 entries, each with `week` and `days[]` (`sun` to `sat`, each with `meals[]`).
  - `shopping_lists`, `reintroduction_schedule`, `sauces`, `known_issues`, `meta` and `schema_note` are **ignored** by the importer.

**Profiles**
- `amel` is the full gut program plus the meal plan.
- `nina` is the meal plan only.

---

## 2. Code conventions (copy the existing style)

- SwiftData models are `@Model final class`, every stored property has a default value, and enums are stored as `xxxRaw: String` with a computed accessor. See `ReintroTest.swift` for the pattern.
- Dates are always stored as `Calendar.current.startOfDay(for:)`.
- Use one file per type. Use `private struct` for subviews inside a view file, as `TodayView.swift` does.
- Pure logic, meaning anything that doesn't need SwiftData or SwiftUI, lives in `Shared/MealPlan/Logic/` as plain `struct` or `enum` types, so it can be unit tested.
- After any write to the store, call `try? context.save()`. The gut-program code still uses `ProgramActions.didChange`; the meal plan code does not need it.
- Numbers shown to the user: kcal as whole numbers, grams with at most 1 decimal, via `.formatted(.number.precision(.fractionLength(0...1)))`.
- No new third-party dependencies.

**Build command** (run from the repo root):

```
xcodebuild -project GutHealthFoodCheck.xcodeproj -scheme GutHealthFoodCheck \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO build
```

**Test command:** the same, with `test` instead of `build`. If `iPhone 16` doesn't exist, run `xcrun simctl list devices available` and pick any available iPhone.

---

## 3. Target folder layout (created across the tasks)

```
Shared/MealPlan/
  Models/        Profile.swift, CatalogIngredient.swift, MealDefinition.swift, MealItem.swift,
                 MealStep.swift, PlanEntry.swift, DayOverride.swift, MealCompletion.swift,
                 PersonTargets.swift, MealPlanSettings.swift, ShoppingListItem.swift
  Logic/         Macros.swift, MealResolver.swift, DaySummary.swift, ShoppingGenerator.swift,
                 QuantityFormat.swift
  Import/        MealPlanDTO.swift, MealPlanImporter.swift
GutHealthFoodCheck/Views/MealPlan/
  ProfilePickerView.swift, NinaHomeView.swift, DayHeaderView.swift, DaySummaryCard.swift,
  MealRowView.swift, MealDetailView.swift, MealEditView.swift,
  ShoppingListView.swift, MealPlanSettingsView.swift, ImportPlanView.swift, StepsView.swift
GutHealthFoodCheckTests/
  MacrosTests.swift, MealResolverTests.swift, ImporterTests.swift, ShoppingGeneratorTests.swift
```

---

## Task 1: Profile and first-launch picker

**Goal:** On first launch the app asks "Amel or Nina", remembers the answer, and gates the gut-program features to Amel.

**Read first:** `GutHealthFoodCheckApp.swift`, `Views/RootView.swift`, `Program/ProgramActions.swift`, `Program/ReminderScheduler.swift`

**Create `Shared/MealPlan/Models/Profile.swift`:**
```swift
import Foundation

enum Profile: String, CaseIterable, Identifiable {
    case amel, nina
    var id: String { rawValue }
    var displayName: String { self == .amel ? "Amel" : "Nina" }
    var hasGutProgram: Bool { self == .amel }
    static let storageKey = "profile"   // @AppStorage key; empty string = not chosen yet
}
```

**Create `GutHealthFoodCheck/Views/MealPlan/ProfilePickerView.swift`:** a full-screen view with the title "Who's using this phone?" and two large bordered buttons, "Amel" and "Nina". Tapping one sets `@AppStorage(Profile.storageKey)` to the profile's `rawValue`.

**Modify `RootView.swift`:**
- Add `@AppStorage(Profile.storageKey) private var profileRaw = ""`.
- If `Profile(rawValue: profileRaw)` is nil, show `ProfilePickerView`.
- If the profile is `.amel`, show the existing `TabView`, unchanged.
- If the profile is `.nina`, show `Text("Nina home")` as a placeholder. Task 7 replaces it.
- Move the existing `.task`, `.onChange(of: scenePhase)` and `.onOpenURL` modifiers so they apply **only** to the Amel branch. That keeps Nina from triggering `seedIfNeeded`, notification permission, or reminders.

**Acceptance**
- A fresh install shows the picker, and relaunching after picking skips it.
- Picking Nina never shows the notification permission prompt. (Erase the simulator to test: *Device → Erase All Content and Settings*.)
- Picking Amel behaves exactly like the app did before.

---

## Task 2: SwiftData models

**Goal:** Add the meal plan models and register them in the schema. There's no UI in this task.

**Read first:** `Shared/Models/ReintroTest.swift`, `Shared/Program/SharedStore.swift`

**Create these files in `Shared/MealPlan/Models/`.** Each is a `@Model final class` with defaults on every property and an `init` that sets the listed fields.

```swift
// CatalogIngredient.swift
var key: String = ""            // json ingredients[].id, or "gf_bread_slice"
var name: String = ""
var unit: String = "g"          // "g" | "ml" | "pcs"
var aisle: String = "other"
var macroBasisRaw: String = "per_100g"   // "per_100g" | "per_100ml" | "per_piece"
var kcal: Double = 0
var protein: Double = 0
var carbs: Double = 0
var fat: Double = 0
var fibre: Double = 0
var cookedToDryRatio: Double? = nil
var note: String = ""
var labelCheck: Bool = false
var isStaple: Bool = false      // excluded from shopping lists
/// JSON array of {"key": String, "amount": Double} that one unit of this item expands to
/// when shopping. Empty for normal ingredients. Used for gf_bread_slice (1/10 of the loaf).
var shoppingExpansionJSON: String = ""

// MealItem.swift
var order: Int = 0
var ingredientKey: String = ""
var name: String = ""
var unit: String = "g"
var quantity: Double = 0
var baseQuantity: Double = 0
var baseKcal: Double = 0
var baseProtein: Double = 0
var baseCarbs: Double = 0
var baseFat: Double = 0
var baseFibre: Double = 0
var component: String = ""
var state: String = ""          // "", "raw", "cooked", "dry", "drained"
var note: String = ""
var meal: MealDefinition?

// MealStep.swift
var order: Int = 0
var text: String = ""
var isDone: Bool = false        // checkmark while cooking; cleared with "Uncheck all"
var meal: MealDefinition?

// MealDefinition.swift
var key: String = ""            // json meals[].id; copies are "<key>@yyyy-MM-dd"
var person: String = ""         // "amel" | "nina"
var slot: String = ""           // "breakfast", "lunch", "pre_workout", "dinner", "snack"
var name: String = ""
var notes: String = ""
var isTemplate: Bool = true     // false for copy-on-write copies
@Relationship(deleteRule: .cascade, inverse: \MealItem.meal) var items: [MealItem] = []
@Relationship(deleteRule: .cascade, inverse: \MealStep.meal) var steps: [MealStep] = []
// computed: sortedItems, sortedSteps (sorted by order)

// PlanEntry.swift: one meal slot in the repeating plan
var person: String = ""
var weekIndex: Int = 0          // amel: always 0; nina: 0 or 1
var weekday: Int = 1            // Calendar weekday: 1 = Sunday ... 7 = Saturday
var order: Int = 0              // position within the day
var mealKey: String = ""
var training: String = ""       // amel only, e.g. "weightlifting"

// DayOverride.swift: a date whose meal list differs from the plan
var person: String = ""
var date: Date = Date()         // startOfDay
var mealKeys: [String] = []     // ordered

// MealCompletion.swift: presence means eaten
var person: String = ""
var date: Date = Date()         // startOfDay
var mealKey: String = ""

// PersonTargets.swift
var person: String = ""
var kcal: Double = 0
var proteinMin: Double = 0      // protein_g, or protein_g_min
var proteinMax: Double? = nil   // protein_g_max when it's a range
var carbs: Double? = nil        // nil = no target, show eaten only
var fat: Double? = nil
var fibre: Double? = nil

// MealPlanSettings.swift: single record
var importedAt: Date? = nil
var rotationStart: Date = Date()   // a Sunday; Nina's week 1 begins here
var shoppingStart: Date = Date()
var shoppingDays: Int = 7
var shoppingHousehold: Bool = true

// ShoppingListItem.swift
var name: String = ""
var quantity: Double = 0
var unit: String = ""
var aisle: String = "other"
var order: Int = 0
var isChecked: Bool = false
var isManual: Bool = false
var sourceKey: String = ""      // ingredient key for generated items
```

**Modify `SharedStore.swift`:** append all 11 new model types to `schema`, after the existing five.

**Acceptance**
- The app builds and launches. Existing gut data on a device that already has the app is still there (lightweight migration).
- The widget target still builds.

---

## Task 3: Macro math and quantity formatting (pure logic, with tests)

**Read first:** Task 2's `MealItem.swift` and `CatalogIngredient.swift`

**Create `Shared/MealPlan/Logic/Macros.swift`:**
```swift
struct Macros: Equatable {
    var kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0, fibre = 0.0
    static let zero = Macros()
    static func + (a: Macros, b: Macros) -> Macros   // field-wise
    func scaled(by factor: Double) -> Macros          // field-wise multiply
}
enum MacroMath {
    /// Macros for `amount` of a catalog item. per_100g / per_100ml → × amount/100; per_piece → × amount.
    static func macros(catalog: CatalogValues, amount: Double) -> Macros
    /// Current macros of an item: base × (quantity / baseQuantity). Returns .zero if baseQuantity <= 0.
    static func current(base: Macros, baseQuantity: Double, quantity: Double) -> Macros
}
/// Plain copy of catalog numbers so the logic doesn't depend on SwiftData.
struct CatalogValues { var basis: String; var kcal, protein, carbs, fat, fibre: Double }
```

Also add convenience extensions **in the model files**: `MealItem.baseMacros`, `MealItem.macros` (uses `MacroMath.current`), `MealDefinition.macros` (sum of items), and `CatalogIngredient.values`.

**Create `Shared/MealPlan/Logic/QuantityFormat.swift`:** `QuantityFormat.string(_ quantity: Double, unit: String) -> String`.
- `g` with quantity ≥ 1000 → `"1.05 kg"`. `ml` with quantity ≥ 1000 → `"1.85 L"`. Use at most 2 decimals, with trailing zeros trimmed.
- Otherwise show the quantity with at most 1 decimal followed by the unit, e.g. `"200 g"`, `"1.5 pcs"`.

**Create `GutHealthFoodCheckTests/MacrosTests.swift`:**
- Eggs at 75 kcal per piece and 3 pcs give 225 kcal.
- Skyr at 63 kcal per 100 g and 100 g gives 63 kcal.
- With base 225 kcal at 3 pcs: quantity 4 gives 300, and quantity 3 gives exactly 225 again.
- `baseQuantity` 0 gives `.zero`.
- `QuantityFormat`: 1050 g gives "1.05 kg", 1850 ml gives "1.85 L", 200 g gives "200 g".

**Acceptance:** the tests pass.

---

## Task 4: Importer (with tests)

**Goal:** Parse `meal-plan.json` and replace all meal plan data in the store.

**Read first:** `docs/meal-plan.json`, and all of the Task 2 models

**Create `Shared/MealPlan/Import/MealPlanDTO.swift`:** `Decodable` structs that mirror only the parts of the JSON listed in section 1. Use `CodingKeys` for snake_case fields. Treat optional fields as optionals, and decode `amount` as `Double`.

**Create `Shared/MealPlan/Import/MealPlanImporter.swift`:**
```swift
enum MealPlanImportError: LocalizedError { case invalidJSON(String), missingMeal(String), missingIngredient(meal: String, ingredient: String) }
struct MealPlanImportSummary { var meals: Int; var ingredients: Int; var people: [String] }
@MainActor
enum MealPlanImporter {
    static func importPlan(data: Data, into context: ModelContext, now: Date = .now) throws -> MealPlanImportSummary
}
```

`importPlan` must do the following, in order:
1. Decode the DTO. If decoding fails, throw `invalidJSON` with the error's `localizedDescription`.
2. Validate before writing anything:
   - every meal id referenced in `plans` exists in `meals`
   - every item's `ingredient` exists in `ingredients` or is `gf_bread_slice`

   Throw the matching error if either check fails.
3. Delete **all** existing `CatalogIngredient`, `MealDefinition` (which cascades to items and steps), `PlanEntry`, `DayOverride`, `MealCompletion` and `PersonTargets` records. **Keep** `ShoppingListItem` records where `isManual == true` and delete the rest.
4. Insert one `CatalogIngredient` per JSON ingredient.
   - Set `isStaple = true` for the keys `coffee`, `salt`, `sugar` and `vanilla_sugar`.
   - Also insert `gf_bread_slice`: name "Gluten-free bread (homemade slice)", unit `pcs`, basis `per_piece`, macros from `recipes.gf_bread_slice`, and aisle `pantry`.
   - Set the bread's `shoppingExpansionJSON` to the loaf's `per_loaf` items with each `amount` multiplied by 0.1 (`per_loaf_fraction`). Skip any loaf ingredient that isn't in the catalog, such as `water`.
5. For each JSON meal, insert a `MealDefinition` with `isTemplate = true`, and one `MealItem` per item with `order` = index.
   - Set `baseQuantity = quantity = amount`, and the base macros from `MacroMath.macros(catalog:amount:)` using that item's catalog entry.
   - Take `name` from the catalog entry and `unit` from the item. Insert no steps; the JSON has none.
6. Insert the `PlanEntry` records:
   - **amel:** each `days[i]` maps its `day` string to a weekday (`sun` is 1 … `sat` is 7). Set `weekIndex` 0, `order` = index within `meals`, and copy `training`.
   - **nina:** each `weeks[w].days[i]` gets `weekIndex = w` (0-based) and the same weekday mapping.
7. Insert a `PersonTargets` per person: `kcal`; `proteinMin` from `protein_g` or `protein_g_min`; `proteinMax` from `protein_g_max`; leave carbs, fat and fibre nil.
8. Create or update the single `MealPlanSettings` record: `importedAt = now`, and `rotationStart` = the first Sunday on or after `startOfDay(now)`. If a record already exists, keep its `rotationStart`.
9. Call `context.save()` and return the summary.

**Create `GutHealthFoodCheckTests/ImporterTests.swift`:** use an in-memory container, `ModelConfiguration(schema: SharedStore.schema, isStoredInMemoryOnly: true)`, and load `Fixtures/meal-plan.json` via `Bundle(for:)`.
- The import succeeds, with 23 meals and 14 `PlanEntry` days for nina (2 weeks × 7).
- `amel_dinner` computes to about 316 kcal (±2) and about 37.7 g protein (±0.5).
- Amel's Monday entries sum to about 2,169 kcal (±5).
- Importing twice gives the same counts, with no duplicates.
- A meal that references an unknown ingredient throws `missingIngredient`.

**Acceptance:** the tests pass.

---

## Task 5: Meal resolver and day summary (with tests)

**Create `Shared/MealPlan/Logic/MealResolver.swift`:**
```swift
struct ResolvedDay { var date: Date; var mealKeys: [String]; var training: String; var isOverride: Bool }
enum MealResolver {
    /// entries/overrides are plain values copied from the models.
    static func resolve(person: String, date: Date, rotationStart: Date,
                        entries: [PlanEntrySnapshot], overrides: [DayOverrideSnapshot],
                        calendar: Calendar = .current) -> ResolvedDay
}
struct PlanEntrySnapshot { var person: String; var weekIndex: Int; var weekday: Int; var order: Int; var mealKey: String; var training: String }
struct DayOverrideSnapshot { var person: String; var date: Date; var mealKeys: [String] }
```

The resolution rules:
1. `day = startOfDay(date)`. If an override exists for `(person, day)`, return its `mealKeys` with `isOverride = true` and `training` from rule 2.
2. Take `weekday = calendar.component(.weekday, from: day)`.
3. **amel:** use entries with `weekIndex == 0` and a matching weekday, sorted by `order`.
4. **nina:**
   - `days = calendar.dateComponents([.day], from: startOfDay(rotationStart), to: day).day!`
   - `week = ((days / 7) % 2 + 2) % 2`. Use floor division, so negative values work: `Int(floor(Double(days) / 7))`.
   - Use entries with that `weekIndex` and weekday, sorted by `order`.
5. `training` is the first matching entry's training, or `""`.

**Create `Shared/MealPlan/Logic/DaySummary.swift`:**
```swift
struct DaySummary {
    var target: TargetsSnapshot; var eaten: Macros; var planned: Macros
    var kcalLeft: Double { target.kcal - eaten.kcal }   // negative = over
}
struct TargetsSnapshot { var kcal: Double; var proteinMin: Double; var proteinMax: Double?; var carbs: Double?; var fat: Double?; var fibre: Double? }
enum DaySummaryBuilder {
    static func build(meals: [(key: String, macros: Macros)], eatenKeys: Set<String>, target: TargetsSnapshot) -> DaySummary
}
```

**Create `GutHealthFoodCheckTests/MealResolverTests.swift`:** use a fixed Gregorian calendar with the Europe/Berlin time zone.
- Amel on any Wednesday returns his 4 meals in order.
- With Nina's `rotationStart` set to Sunday 2026-10-11:
  - 2026-10-11 resolves to week 0, Sunday
  - 2026-10-18 resolves to week 1, Sunday
  - 2026-10-25 resolves to week 0 again
  - 2026-10-10, the Saturday before the start, resolves to week 1, Saturday
- An override for one date replaces that date's meals and leaves the next day untouched.
- In the summary, only eaten keys count toward `eaten`, and `kcalLeft` goes negative when you're over target.

**Acceptance:** the tests pass.

---

## Task 6: Shared day UI components

**Goal:** Build the reusable views used by both homes. No navigation wiring yet.

**Read first:** `Views/TodayView.swift` (for styling), and the Task 3 and Task 5 logic files

**Create in `GutHealthFoodCheck/Views/MealPlan/`:**
- **`DayHeaderView`**
  - Takes `@Binding var date: Date`.
  - Shows a "‹" button, a compact `DatePicker` (`.datePickerStyle(.compact)`, date only), and a "›" button. The arrows move by ±1 day.
  - Shows a "Today" button only when `date` isn't today.
  - Takes an optional `training: String`, shown as a caption under the date when it isn't empty.
- **`DaySummaryCard`**
  - Takes a `DaySummary`.
  - The top row has three columns: Left, Eaten and Total kcal. When Left is negative, show "+X over" in `.orange`.
  - Below that, a 2×2 grid shows protein, carbs, fat and fibre as `eaten / target g`.
  - Protein shows its range (`130–150`) when `proteinMax` is set.
  - Macros without a target (nil) show `eaten g` only.
- **`MealRowView`**
  - Inputs: `title` (from the slot, prettified: `pre_workout` becomes "Pre-workout"), `name`, `summary` (the first 3 item names joined with " + ", plus "…" if there are more), `kcal`, `isEaten`, an optional `testAddition: String?`, and an `onToggle` closure.
  - The checkmark button on the right uses `checkmark.circle.fill` (green) or `circle` (secondary), with `.sensoryFeedback(.success, trigger: isEaten)`.
  - The rest of the row is **not** the button. The parent wraps the row in a `NavigationLink`, and the check button needs `.buttonStyle(.borderless)` so it doesn't trigger the link.
  - `testAddition`, when present, appears as a blue `Label(..., systemImage: "plus.circle.fill")` line, like the existing `MealRow`.

Add a `#Preview` with sample data for each view.

**Acceptance:** the previews render. The app builds.

---

## Task 7: Nina's home screen

**Read first:** `RootView.swift`, the Task 6 views, `MealResolver.swift`, `DaySummary.swift`

**Create `NinaHomeView.swift`:**
- It's a `NavigationStack` with `List`, titled "Meals".
- `@State private var date = Calendar.current.startOfDay(for: .now)`.
- It uses `@Query` to load the following, filtered in code to `person == "nina"` where relevant:
  - all `PlanEntry`
  - all `DayOverride`
  - all `MealDefinition`
  - all `MealCompletion`
  - all `PersonTargets`
  - all `MealPlanSettings`
- **Sections:**
  - The first section holds `DayHeaderView` and then `DaySummaryCard`.
  - The second section, "Meals", holds one `MealRowView` per resolved meal key, each wrapped in a `NavigationLink(value: mealKey)`.
  - Add `.navigationDestination(for: String.self)`, which shows `Text(key)` as a placeholder until Task 9.
- **Toggling a meal:** insert or delete the `MealCompletion(person:date:mealKey:)` for `startOfDay(date)`, then call `context.save()`.
- **Toolbar:** a cart button opens `ShoppingListView` (a placeholder `Text` until Task 11), and a gear button opens settings (a placeholder until Task 12).
- **Empty states:**
  - If no `MealPlanSettings` record exists, or `importedAt == nil`, show a `ContentUnavailableView` titled "Import your meal plan" with an "Import" button. It opens `ImportPlanView` (Task 8).
  - If the date resolves to no meals, show "No meals planned for this day".

**Modify `RootView.swift`:** replace Nina's placeholder with `NinaHomeView()`.

**Acceptance:** with the Task 4 test data imported (Task 8 makes that possible from the UI; until then, test it in a preview with an in-memory container), Nina's Sunday 2026-10-11 shows 5 meals. Checking breakfast moves Eaten from 0 to 567 kcal, and unchecking it moves it back to 0.

---

## Task 8: Import screen

**Create `ImportPlanView.swift`:**
- A sheet with an explanation line, a "Choose file" button that uses `.fileImporter(allowedContentTypes: [.json])`, and a result area.
- Read the file's data with `url.startAccessingSecurityScopedResource()` and the matching stop call.
- If any `MealDefinition` already exists, confirm first with an alert: "Replace the current meal plan? Checkmarks and edits are removed. Shopping items you added yourself are kept."
- Call `MealPlanImporter.importPlan`. On success, show "Imported N meals for Amel and Nina" and a Done button. On failure, show the error's `localizedDescription` in red.

**Wire it up:** the empty-state button in `NinaHomeView`. Amel's entry point comes in Task 10.

**Acceptance:** AirDrop or drag `meal-plan.json` into the simulator's Files app, import it, and Nina's home fills with meals.

---

## Task 9: Meal detail and copy-on-write editing

**Read first:** `MealDefinition.swift`, `MealItem.swift`, `DayOverride.swift`, `MealCompletion.swift`, `Macros.swift`

**Create `Shared/MealPlan/Logic/MealEditing.swift`:** a `@MainActor enum MealEditing`. It touches SwiftData, so it doesn't need unit tests.
- **`editableMeal(key:person:date:context:) -> MealDefinition`**
  - If the meal with `key` has `isTemplate == false`, return it.
  - Otherwise:
    1. Ensure a `DayOverride` exists for `(person, date)`. If it doesn't, create one with the date's currently resolved keys.
    2. Deep-copy the meal (items and steps) under the new key `"\(key)@\(yyyy-MM-dd)"`, with `isTemplate = false`.
    3. Replace `key` in `override.mealKeys` with the new key.
    4. If a `MealCompletion` exists for `(person, date, key)`, change its `mealKey` to the new key.
    5. Save and return the copy.
- **`addMeal(person:date:slot:name:context:) -> MealDefinition`**: ensure the override as above, then create a new non-template meal with key `"custom-\(UUID().uuidString)@\(yyyy-MM-dd)"` and append it to the override.
- **`removeMeal(key:person:date:context:)`**: ensure the override, then remove the key from it and delete any completion for that key on that date. Don't delete template meals.

**Create `MealDetailView.swift`** (input: `mealKey`, `person`, `date`, and an optional `testAddition`):
- A header with the meal name and its macro totals.
- An "Ingredients" section listing name, `QuantityFormat` quantity, and kcal. Items with a non-empty `state` show it as a caption, e.g. "cooked". If `testAddition` is set, show it as the first row, highlighted in blue.
- A "Notes" section, shown only when notes aren't empty.
- An "Instructions" row, **always shown**, with the subtitle "N steps" or "No steps yet". It's a `NavigationLink` to `StepsView` (Task 13). Until Task 13, push `Text("Instructions")` as a placeholder.
- An eaten toggle.
- An "Edit" toolbar button. It calls `MealEditing.editableMeal`, then pushes `MealEditView` for the result.

**Create `MealEditView.swift`** (it edits a `@Bindable MealDefinition`):
- Fields for name, slot (a `Picker` over the 5 slots) and notes.
- **Ingredients:** each row has a name field and a quantity field (`TextField` with `.decimalPad`), and shows the unit and live kcal. Changing the quantity only sets `item.quantity`; the macros are computed from it.
- Swipe deletes an ingredient. "Add ingredient" opens a searchable list of `CatalogIngredient`. Picking one asks for a quantity and creates a `MealItem` with `baseQuantity = quantity` and base macros from the catalog.
- "Add custom ingredient" asks for name, unit, quantity and all 5 macros for that quantity. Those become its base values.
- Each item also has an "Edit macros" disclosure with 5 number fields. Saving them sets the base macros to the entered values and `baseQuantity` to the current quantity.
- Save on disappear with `context.save()`.

**Wire it up:** replace the `navigationDestination` placeholder in `NinaHomeView` with `MealDetailView`.

**Acceptance**
- Changing Nina's breakfast milk quantity on one date updates that day's kcal, while the same breakfast on the next day is unchanged.
- Changing a quantity and then changing it back gives exactly the original kcal.
- A checkmark that was set before the edit is still set afterwards.

---

## Task 10: Amel's Today tab integration

**Read first:** `Views/TodayView.swift`, `Shared/Program/ProgramEngine.swift`, and the Task 6, 7 and 9 views

**Modify `TodayView.swift`:**
1. Add `@State private var date = startOfDay(.now)` and the same `@Query` properties as `NinaHomeView`, using `person == "amel"`.
2. Keep `PhaseCard` at the top.
3. Insert a new section after it containing `DayHeaderView` (pass the training label) and `DaySummaryCard`.
4. Replace the existing "Today's meals" section, with its three `MealRow` calls:
   - When `MealPlanSettings.importedAt != nil`: one `MealRowView` per resolved meal, each in a `NavigationLink` to `MealDetailView`. The meal with `slot == "lunch"` gets `testAddition`.
     - When `date` is today, use `phase.isTesting ? "\(test.name) \(test.instruction)" : nil` from `engine.phase(on: .now)`.
     - When `date` is in the past, use the `DailyCheckIn` for that day if its `test` is set and its `kind == .test`.
     - When `date` is in the future, use nil.
   - Otherwise, keep the existing three `MealRow` calls, unchanged, as the fallback.
5. Show the "Evening check-in", baseline and "Recent days" sections **only when `date` is today**, exactly as they are now.
6. **Toolbar:** add a cart button for the shopping list next to the existing gear button.
7. **Settings:** in `ProgramSettingsView`, add a "Meal plan" section with a `NavigationLink` to `MealPlanSettingsView`. That view is a placeholder until Task 12, but it needs an "Import plan" row that opens `ImportPlanView` now.

**Acceptance**
- During a test phase, today's lunch shows the test food line.
- Moving to tomorrow shows the meals without the test food, and hides the check-in and baseline sections.
- All existing check-in behaviour works as before.

---

## Task 11: Shopping list (generate, then edit freely)

**Create `Shared/MealPlan/Logic/ShoppingGenerator.swift`:** pure logic, with tests.
```swift
struct ShoppingLine: Equatable { var key: String; var name: String; var quantity: Double; var unit: String; var aisle: String }
enum ShoppingGenerator {
    /// `days`: for each date in range and each person in scope, the items eaten that day.
    static func generate(items: [ShoppingInputItem], catalog: [String: CatalogSnapshot]) -> [ShoppingLine]
}
struct ShoppingInputItem { var ingredientKey: String; var quantity: Double; var unit: String; var state: String }
struct CatalogSnapshot { var name: String; var unit: String; var aisle: String; var cookedToDryRatio: Double?; var isStaple: Bool; var expansion: [(key: String, amount: Double)] }
```

The generation rules, applied in order to each input item:
1. If the catalog entry has a non-empty `expansion`, replace the item with one input per expansion entry, at `amount × quantity` in that ingredient's unit, with an empty state. Then process those inputs from rule 2.
2. If the entry `isStaple`, skip the item.
3. If `state == "cooked"` and `cookedToDryRatio` is set, use `quantity / ratio` and give the line the name `"\(name) (dry)"`.
4. Sum the quantities by `key + unit`.
5. Round up: `g` and `ml` to the next multiple of 5, `pcs` to the next whole number.
6. Sort lines by aisle (in the order `produce`, `dairy_eggs`, `meat_fish`, `pantry`, `frozen`, `supplements`, then anything else), then by name.

**The caller** (in the view) builds the inputs:
- For each day from `shoppingStart` for `shoppingDays` days, and for each person in scope (both people when `shoppingHousehold`, otherwise the current profile only), resolve the day with `MealResolver`.
- Then take every item of every resolved meal, using the current `quantity` so that edits count.

**Create `ShoppingListView.swift`:**
- **Top section "Generate":**
  - a `DatePicker` for the start date
  - a `Stepper` for "N days", from 1 to 28, with quick buttons for 7 and 14
  - a toggle for "Household / Me only"
  - a "Generate list" button
- **Generate button:** if any non-manual items exist, confirm first with "Replace generated items? Items you added yourself are kept." Then:
  1. Delete all `ShoppingListItem` records where `isManual == false`.
  2. Insert the generated lines.
  3. Save the settings values to `MealPlanSettings`.
- **The list:** grouped by aisle into sections with readable titles ("Dairy and eggs", and so on). Each row has a checkbox, the name, and the `QuantityFormat` quantity.
  - Tapping the checkbox toggles `isChecked`, and checked rows sort to the bottom of their section.
  - Tapping the row opens an edit sheet for name, quantity, unit and aisle.
  - Swipe deletes a row.
  - A "+" toolbar button adds a manual item (name, quantity, unit, aisle) with `isManual = true`.
  - A "Reset checks" toolbar menu item sets every `isChecked` to false.
- **Wire it up:** the cart buttons in `NinaHomeView` and `TodayView`.

**Create `GutHealthFoodCheckTests/ShoppingGeneratorTests.swift`:**
- 200 g of cooked rice with a ratio of 2.7 gives "Rice (dry)" at 75 g (74.07 rounded up to the next 5).
- One bread slice expands into the loaf ingredients × 0.1, e.g. flour 45 g and eggs 0.2 rounded up to 1 pcs.
- Staples (coffee) are excluded.
- Two rows with the same key and unit are summed.
- Using the imported fixture for 7 days, household: eggs come out between 45 and 55 pcs (expected 50), and chicken breast between 2,200 and 2,400 g (expected 2,300). (These are sanity bounds; the earlier Markdown list was made before the latest changes.)

**Acceptance**
- The tests pass.
- Generating, deleting an item, adding a manual item and then regenerating keeps the manual item and restores the deleted generated item.

---

## Task 12: Meal plan settings

**Create `MealPlanSettingsView.swift`.** It's used from Nina's gear button and from Amel's `ProgramSettingsView` link.
- **Daily targets** (for the current profile's `PersonTargets`): kcal, protein min, protein max (optional), carbs, fat and fibre. Optional fields have a toggle "Set target"; turning it off sets the value to nil.
- **Plan:** import plan (opens `ImportPlanView`) and the import date. For Nina's profile, also show "Rotation week 1 starts", a `DatePicker` that snaps the chosen date to the Sunday on or before it.
- **Meal templates:** a list of `MealDefinition` where `isTemplate` is true and `person` is the current profile, each opening `MealEditView`. The footer says: "Editing a template changes every day that uses it, except days you've edited separately."
- **Shopping staples:** a list of `CatalogIngredient` with an `isStaple` toggle.
- **Switch profile:** a destructive-styled button behind a confirmation alert. It sets `@AppStorage(Profile.storageKey)` to `""`. No data is deleted.

**Acceptance**
- Changing the kcal target updates the summary card immediately.
- Changing Nina's rotation start shifts which lunch shows on a given date.
- Switching profile returns to the picker.

---

## Task 13: Instructions (editable step checklist)

**Goal:** A simple list of steps for a meal. Each step can be checked off while cooking, and steps can be added, edited, deleted and reordered right in the list. This replaces the full-screen cooking mode from the product document; there's no paging, timer or screen-awake handling.

**Read first:** `MealStep.swift`, `MealDefinition.swift`, `MealDetailView.swift`

**Create `GutHealthFoodCheck/Views/MealPlan/StepsView.swift`** (input: `@Bindable var meal: MealDefinition`):
- A `List`, titled "Instructions", showing `meal.sortedSteps`. Each row has a checkmark button on the left and the step text on the right.
  - The checkmark button toggles `isDone`, using `checkmark.circle.fill` (green) or `circle` (secondary), with `.buttonStyle(.borderless)`.
  - Done steps show their text with `.strikethrough()` and `.foregroundStyle(.secondary)`.
  - Tapping the text opens an edit sheet with a multi-line `TextField` (`axis: .vertical`), plus Save and Cancel. An empty text on Save deletes the step.
  - Swipe deletes a step. `.onMove` reorders, with `EditButton()` in the toolbar. After a move or delete, renumber `order` to 0, 1, 2, and so on.
- **Adding steps:** an "Add step" button as the last row of the list. It opens the same edit sheet, empty, and appends the step with `order` = current count.
- **Toolbar menu:** "Uncheck all" sets every step's `isDone` to false.
- **Empty state:** when there are no steps, show `ContentUnavailableView("No steps yet", systemImage: "list.number", description: Text("Add the steps you follow when cooking this meal."))` with the "Add step" button below it.
- Call `try? context.save()` after every change.

**Important: no copy-on-write for steps.** Steps edit the meal that's shown, directly. For a template meal that means every day using it gets the same steps, which is what you want for instructions. `MealDetailView` must therefore pass the **resolved** meal for that date, the template or the date's copy, and must **not** call `MealEditing.editableMeal` before opening `StepsView`.

**Wire it up:** replace the Instructions placeholder in `MealDetailView` with `StepsView(meal:)`.

**Acceptance**
- A meal with no steps shows "No steps yet" with an "Add step" button, and adding a step makes it appear immediately.
- Steps can be checked, edited, deleted and reordered, and everything survives a relaunch.
- Steps added on Monday's breakfast also appear on Tuesday's breakfast.
- "Uncheck all" clears every checkmark for that meal.

---

## Task 14: Final QA (manual, run by Amel)

Run through this on both physical phones after building from Xcode:

1. Erase the app, install it, pick Nina, and import the plan. Today's meals appear and no notification prompt is shown.
2. Check off 2 meals. Eaten and Left update, and relaunching keeps the checks.
3. Edit one meal's quantity. Only that date changes, and changing it back restores the original kcal.
4. Generate a household shopping list for 7 days, delete 2 items, add 1 manual item, then regenerate. The manual item is kept.
5. On Amel's phone, existing check-ins are intact. Pick Amel, import the plan, and during a test the test food appears on today's lunch only.
6. Amel's day shows about 2,169 kcal planned, with dinner around 316 kcal.
7. Add 3 steps to a meal through Instructions, check one off, relaunch. The steps and the checkmark are still there.
8. The widget still shows the phase on Amel's phone (paid account only).

---

## Data notes for the implementer

- `meal-plan.json` was updated on 2026-10-06. Amel's dinner is now at 50% of the original pancake recipe (316 kcal, 37.7 g protein), and his planned day is about 2,169 kcal and 182 g protein.
- Macros have typical values. Items with `label_check: true` should be checked against the product label later, and can be corrected in the app through "Edit macros".
- The JSON has no cooking steps. Amel and Nina add them in the app as needed, through Instructions on the meal detail page.
