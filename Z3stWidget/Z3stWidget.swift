import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry { SimpleEntry(date: Date(), totalML: 0) }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(SimpleEntry(date: Date(), totalML: Self.readTodayTotal()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entry = SimpleEntry(date: Date(), totalML: Self.readTodayTotal())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
    static func readTodayTotal() -> Int {
        let suite = ProcessInfo.processInfo.environment["APP_GROUP_ID"]
        let defaults = suite.flatMap(UserDefaults.init(suiteName:))
        return defaults?.integer(forKey: "today_total_ml") ?? 0
    }
}

struct SimpleEntry: TimelineEntry { let date: Date; let totalML: Int }

struct Z3stWidgetEntryView : View {
    var entry: Provider.Entry
    var body: some View {
        ZStack {
            ContainerRelativeShape().fill(Color(.systemBackground))
            VStack {
                Text("Water Today")
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(entry.totalML) mL")
                    .font(.title3).bold()
                HStack(spacing: 8) {
                    QuickLogLink(amountML: 250)
                    QuickLogLink(amountML: 500)
                }
            }
            .padding()
        }
    }
}

struct QuickLogLink: View {
    let amountML: Int
    var unit: String {
        let suite = ProcessInfo.processInfo.environment["APP_GROUP_ID"]
        let defaults = suite.flatMap(UserDefaults.init(suiteName:))
        let raw = defaults?.string(forKey: "unit") ?? "mL"
        if raw == "oz" {
            let oz = Double(amountML) / 29.5735
            return String(format: "%.0f oz", oz)
        } else {
            return "\(amountML) mL"
        }
    }
    var body: some View {
        Link(destination: URL(string: "z3st://log?ml=\(amountML)")!) {
            Text(unit).font(.caption2)
                .frame(maxWidth: .infinity)
                .padding(6)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

@main
struct Z3stWidget: Widget {
    let kind: String = "Z3stWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            Z3stWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Z3st Water")
        .description("Shows today's water total.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}
