//
//  LociqWatchWidgets.swift
//  LociqWatchWidgets
//
//  Watch face complications and the Smart Stack widget for LOC IQ.
//
//  The widget reads the small record the watch app leaves in the shared App
//  Group container. It never locates the wearer, never contacts the Census
//  services, and links none of the app's location code; the watch app reloads
//  it whenever it writes a new record.
//

import SwiftUI
import WidgetKit

@main
struct LociqWatchWidgets: WidgetBundle {
    var body: some Widget {
        CityComplication()
    }
}

/// Where LOC IQ last found you, with the city's outline and population.
struct CityComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: CityComplicationEntry.kind, provider: CityComplicationProvider()) { entry in
            CityComplicationWidgetView(entry: entry)
        }
        .configurationDisplayName("City")
        .description("The city where LOC IQ last found you, with its population.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .accessoryCorner])
    }
}

/// Reads the widget family and draws the complication.
private struct CityComplicationWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: CityComplicationEntry

    var body: some View {
        CityComplicationView(entry: entry, family: family)
            .containerBackground(for: .widget) {
                Color.clear
            }
    }
}

/// Builds complication timelines from the watch app's record.
///
/// WidgetKit may call the provider off the main actor.
private nonisolated struct CityComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> CityComplicationEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (CityComplicationEntry) -> Void) {
        completion(context.isPreview ? .sample : Self.entry(at: Date()))
    }

    /// One entry now, and one at midnight, when the complications switch
    /// from the population to the date the city was true. The watch app
    /// reloads the timeline when it writes a new record.
    func getTimeline(in context: Context, completion: @escaping (Timeline<CityComplicationEntry>) -> Void) {
        let now = Date()
        let entry = Self.entry(at: now)
        var entries = [entry]
        if entry.snapshot != nil,
           let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
            entries.append(CityComplicationEntry(date: midnight, snapshot: entry.snapshot))
        }
        completion(Timeline(entries: entries, policy: .never))
    }

    private static func entry(at date: Date) -> CityComplicationEntry {
        CityComplicationEntry(date: date, snapshot: ComplicationSnapshotStore().load())
    }
}
