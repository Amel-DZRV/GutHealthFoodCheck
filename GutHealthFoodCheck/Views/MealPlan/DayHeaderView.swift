import SwiftUI

/// Day navigation for the meal screens: previous / date picker / next, plus a Today shortcut.
struct DayHeaderView: View {
    @Binding var date: Date
    var training: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Button {
                    shift(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Previous day")

                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()

                Button {
                    shift(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Next day")

                Spacer()

                if !Calendar.current.isDateInToday(date) {
                    Button("Today") {
                        date = Calendar.current.startOfDay(for: .now)
                    }
                    .buttonStyle(.borderless)
                    .font(.subheadline.bold())
                }
            }
            if !training.isEmpty {
                Text(training)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: date) { _, new in
            let day = Calendar.current.startOfDay(for: new)
            if day != new { date = day }
        }
    }

    private func shift(by days: Int) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        date = calendar.date(byAdding: .day, value: days, to: start) ?? start
    }
}

#Preview {
    @Previewable @State var date = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400 * 2))
    List {
        DayHeaderView(date: $date, training: "Gym: lower body")
    }
}
