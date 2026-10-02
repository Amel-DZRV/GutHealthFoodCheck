# GutHealthFoodCheck

A small iOS app (SwiftUI + SwiftData, iOS 17+) for figuring out which foods make you bloat.

## Features

- **Foods grouped by FODMAP category** in collapsible sections: Fructans, GOS, Lactose,
  Excess Fructose, Sorbitol, Mannitol, Low FODMAP, Mixed / Unsure. Collapsed state is remembered.
- **A food is a name + portion** (g or ml). "Banana 50 g" and "Banana 150 g" are separate items,
  because FODMAP tolerance usually depends on the amount.
- **Duplicate check** when adding: matching ignores case, accents and extra spaces. If the same name
  and portion already exists you can't save a copy, and the form offers to log a reaction to the
  existing item instead. Other portions of the same food are listed for reference.
- **Reaction logs** per food: date/time, bloating 0–10, abdominal pain 0–10, gas (none to severe),
  stool (Bristol scale 1–7), when symptoms started, what else was in the meal, and notes.
- **Tolerance badge** per food (Not tested / Tolerated / Caution / Trigger), based on the average
  of each log's worst symptom (bloating, pain, or gas).
- Search, swipe to delete, and edit foods.
- All data is stored locally on the device with SwiftData.

## Running

1. Open `GutHealthFoodCheck.xcodeproj` in Xcode 16 or newer.
2. Choose your Team under *Signing & Capabilities* (and change the bundle identifier if needed).
3. Run on an iOS 17+ simulator or device.

## Project layout

```
GutHealthFoodCheck/
  GutHealthFoodCheckApp.swift   App entry, SwiftData container
  Models/                       FoodItem, SymptomLog, FODMAP categories, symptom scales
  Views/                        List, add/edit food, food detail, log reaction
```
