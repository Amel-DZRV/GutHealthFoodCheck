import Foundation

/// The "Full Reintroduction Meal Schedule": 17 foods plus lactose, in test order.
/// FODMAP categories follow Monash; several foods are low FODMAP at these amounts
/// and act as useful controls.
enum DefaultPlan {
    static let lunch = "220 g chicken or fish · 200 g cooked rice (or potato) · 100 g spinach or salad leaves · 150 g cucumber and tomato · ~12 g olive oil"

    static func makeTests() -> [ReintroTest] {
        let rows: [(String, String, FODMAPCategory, Double, PortionUnit, String, String, Int)] = [
            ("Onion", "Fructan", .fructans, 30, .grams, "", "cooked, in with the protein", 3),
            ("Garlic", "Fructan", .fructans, 3, .grams, "1 clove", "cooked into the protein", 3),
            ("Banana", "Fruit", .fructans, 100, .grams, "", "on the side", 3),
            ("Strawberries", "Fruit", .lowFODMAP, 100, .grams, "", "on the side", 3),
            ("Apples", "Fruit", .mixed, 100, .grams, "", "on the side", 3),
            ("Grapes", "Fruit", .fructose, 100, .grams, "", "on the side", 3),
            ("Blueberries", "Fruit", .lowFODMAP, 100, .grams, "", "on the side", 3),
            ("Raspberries", "Fruit", .lowFODMAP, 100, .grams, "", "on the side", 3),
            ("Broccoli", "Cruciferous veg", .fructose, 75, .grams, "", "replacing part of the greens", 3),
            ("Cauliflower", "Cruciferous veg", .mannitol, 75, .grams, "", "replacing part of the greens", 3),
            ("Oats (gluten-free)", "Grain / fibre", .fructans, 40, .grams, "~40 g dry", "replacing the rice", 3),
            ("Peanuts", "Nut", .lowFODMAP, 20, .grams, "", "on the side", 3),
            ("Cashews", "Nut", .mixed, 20, .grams, "", "on the side", 3),
            ("Almonds", "Nut", .gos, 20, .grams, "", "on the side", 3),
            ("Walnuts", "Nut", .lowFODMAP, 20, .grams, "", "on the side", 3),
            ("Chia seeds", "Seed", .lowFODMAP, 10, .grams, "", "stirred into the salad", 3),
            ("Flax seeds", "Seed", .lowFODMAP, 10, .grams, "", "stirred into the salad", 3),
            ("Lactose (milk)", "Disaccharide", .lactose, 200, .milliliters, "~200 ml milk or ~150 g yogurt", "daily, with lunch", 7),
        ]
        return rows.enumerated().map { index, row in
            ReintroTest(
                order: index,
                name: row.0,
                group: row.1,
                category: row.2,
                amount: row.3,
                unit: row.4,
                portionNote: row.5,
                howToAdd: row.6,
                durationDays: row.7
            )
        }
    }

    /// The coming Monday, or today if it is Monday.
    static func nextMonday(from date: Date = .now) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        if calendar.component(.weekday, from: today) == 2 { return today }
        return calendar.nextDate(after: today, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime) ?? today
    }
}
