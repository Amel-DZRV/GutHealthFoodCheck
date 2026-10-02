import SwiftData
import SwiftUI
import WidgetKit

@main
struct GutCheckWidgetBundle: WidgetBundle {
    var body: some Widget {
        GutCheckWidget()
    }
}

struct GutCheckWidget: Widget {
    let kind = "GutCheckWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GutCheckWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "gutcheck://checkin"))
        }
        .configurationDisplayName("Gut Check")
        .description("Today's plan and whether you've logged tonight.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Timeline

struct DayScore: Identifiable {
    let day: Date
    let bloating: Int?
    let gas: Int?

    var id: Date { day }
}

struct GutCheckEntry: TimelineEntry {
    let date: Date
    let badge: String
    let title: String
    let detail: String
    let isTesting: Bool
    let loggedToday: Bool
    let recent: [DayScore]

    static let sample = GutCheckEntry(
        date: .now,
        badge: "TEST · DAY 2/3",
        title: "Onion",
        detail: "Add to lunch: ~30 g, cooked, in with the protein.",
        isTesting: true,
        loggedToday: false,
        recent: (0..<7).map { offset in
            DayScore(
                day: Calendar.current.date(byAdding: .day, value: offset - 6, to: .now) ?? .now,
                bloating: [0, 1, 0, 1, 2, 1, nil][offset],
                gas: [1, 0, 1, 1, 1, 2, nil][offset]
            )
        }
    )

    static let notSetUp = GutCheckEntry(
        date: .now,
        badge: "GUT CHECK",
        title: "Open the app",
        detail: "Open Gut Check once to set up your plan.",
        isTesting: false,
        loggedToday: false,
        recent: []
    )
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> GutCheckEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (GutCheckEntry) -> Void) {
        completion(context.isPreview ? .sample : makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GutCheckEntry>) -> Void) {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        // Refresh just after midnight so "today" rolls over; the app reloads on every change.
        completion(Timeline(entries: [makeEntry()], policy: .after(tomorrow.addingTimeInterval(60))))
    }

    private func makeEntry() -> GutCheckEntry {
        guard let container = try? SharedStore.makeContainer() else { return .notSetUp }
        let context = ModelContext(container)
        let engine = SharedStore.engine(context)
        guard engine.settings != nil else { return .notSetUp }

        let now = Date.now
        let phase = engine.phase(on: now)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let recent = (0..<7).compactMap { offset -> DayScore? in
            guard let day = calendar.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
            let checkIn = engine.checkIn(on: day)
            return DayScore(day: day, bloating: checkIn?.bloating, gas: checkIn?.gas)
        }

        return GutCheckEntry(
            date: now,
            badge: phase.badge,
            title: phase.title,
            detail: phase.detail,
            isTesting: phase.isTesting,
            loggedToday: engine.checkIn(on: now) != nil,
            recent: recent
        )
    }
}

// MARK: - Views

struct GutCheckWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GutCheckEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            lockScreen
        case .systemMedium:
            HStack(spacing: 16) {
                summary
                RecentBars(days: entry.recent)
            }
        default:
            summary
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.badge)
                .font(.caption2.bold())
                .foregroundStyle(entry.isTesting ? Color.blue : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(entry.title)
                .font(.title3.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            if family == .systemMedium {
                Text(entry.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
            status
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var status: some View {
        if entry.loggedToday {
            Label("Logged", systemImage: "checkmark.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.green)
        } else {
            Label("Log tonight", systemImage: "square.and.pencil")
                .font(.caption.bold())
                .foregroundStyle(.tint)
        }
    }

    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.badge)
                .font(.caption2)
                .lineLimit(1)
            Text(entry.title)
                .font(.headline)
                .lineLimit(1)
            Text(entry.loggedToday ? "✓ Logged today" : "Log bloating & gas tonight")
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Last 7 days: bloating and gas bars (0–5) per day.
private struct RecentBars: View {
    let days: [DayScore]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bloating · Gas")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(days) { day in
                    VStack(spacing: 3) {
                        HStack(alignment: .bottom, spacing: 2) {
                            bar(day.bloating)
                            bar(day.gas)
                        }
                        .frame(height: 50, alignment: .bottom)
                        Text(day.day, format: .dateTime.weekday(.narrow))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bar(_ value: Int?) -> some View {
        if let value {
            Capsule()
                .fill(Color.forScore(Double(value)))
                .frame(width: 5, height: max(4, CGFloat(value) / 5 * 50))
        } else {
            Capsule()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 5, height: 4)
        }
    }
}

#Preview(as: .systemMedium) {
    GutCheckWidget()
} timeline: {
    GutCheckEntry.sample
}
