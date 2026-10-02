# GutHealthFoodCheck

An iOS app (SwiftUI + SwiftData + WidgetKit, iOS 17+) for running a **baseline week followed by
a one-food-at-a-time FODMAP reintroduction**, and for tracking which foods make you bloat.

## Tabs

### Today
- What today is: *Baseline · day 4/7*, *Test · day 2/3: Onion*, *Settling*, or *Plan complete*.
- Your standard breakfast, lunch and dinner. On test days, lunch shows the test food and how to add it.
- **Evening check-in**: bloating and gas (0–5) for the whole day, plus optional pain, Bristol stool
  type and notes. Tap any day to edit or delete it.
- During the baseline: progress, averages, and a check on whether the baseline was calm
  (no day above 2) before you tap **Start reintroduction**.

### Plan
The 17 foods plus lactose from the *Full Reintroduction Meal Schedule*, in order, with amount,
how each goes into lunch, and live status (Next / Day 2/3 / Tolerated / Reaction · day 2 / Skipped).
Reorder with Edit, swipe to skip, tap to edit, + to add.

### Foods
Foods in collapsible FODMAP sections, identified by name + portion, with a duplicate check and
ad-hoc reaction logs. Finished reintroduction tests are written here automatically
(e.g. "Onion · 30 g: Reaction on test day 2 of 3").

## Program rules

| Rule | Value |
| --- | --- |
| Scale | 0–5 for bloating, gas and pain |
| Baseline | 7 logged days (more if you want) |
| Test block | 3 logged days per food, 7 for lactose. Days count only when logged. |
| Reaction | Bloating **or** gas ≥ baseline average + 2, or "I reacted" toggled |
| After a reaction | Plain baseline lunch until 2 calm days in a row (within +1 of baseline), then the next food |

Everything is derived from your check-ins, so editing or deleting a day recalculates all results.

## Reminders and widget
- **Evening reminder**: a banner notification (also shown while the app is open) at a time you pick
  in Settings, default 20:00. Today's reminder is skipped once you've logged. Tapping it opens the check-in.
- **Widget**: small, medium (with a 7-day bloating/gas chart) and Lock Screen. Shows today's phase
  and whether tonight is logged; tapping opens the check-in.

## Running
1. Open `GutHealthFoodCheck.xcodeproj` in Xcode 16 or newer.
2. Select your Team for **both** targets (`GutHealthFoodCheck` and `GutCheckWidgetExtension`) under
   *Signing & Capabilities*. If the bundle IDs are taken, change `com.guthealth` in both targets and
   the App Group (`group.com.guthealth.GutHealthFoodCheck`) in `Config/*.entitlements` and
   `Shared/Program/SharedStore.swift`.
3. Run on an iOS 17+ device or simulator.

The widget reads the app's data through an **App Group**, which needs a paid Apple Developer account.
With a free account the app still works fully, but the widget shows "Open the app".

## Project layout
```
GutHealthFoodCheck/   App: entry point, program actions, reminders, views
Shared/               Compiled into app and widget: SwiftData models, program engine, store
GutCheckWidget/       Widget extension
Config/               Entitlements and Info.plist additions
```
