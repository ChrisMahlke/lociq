//
//  CityComplicationEntry.swift
//  LociqWatch
//
//  One complication state: the record the watch app left, at one moment.
//

import CoreGraphics
import Foundation
import WidgetKit

/// A complication timeline entry.
nonisolated struct CityComplicationEntry: TimelineEntry, Sendable {
    /// Widget kind, which the watch app reloads after writing a record.
    static let kind = "CityComplication"

    /// When WidgetKit shows this entry.
    let date: Date

    /// Where the watch app last found the wearer, or `nil` before it has.
    let snapshot: ComplicationSnapshot?

    /// True when the record was confirmed the same day as this entry.
    ///
    /// Complications show the population on that day, and the date after it.
    var isFromToday: Bool {
        snapshot?.isConfirmed(onSameDayAs: date) ?? false
    }

    /// Sample for the complication gallery: text and a simple outline, not real data.
    static let sample = CityComplicationEntry(
        date: Date(),
        snapshot: ComplicationSnapshot(
            kind: .city,
            title: "YOUR CITY, ST",
            shortTitle: "YOUR CITY",
            subtitle: "",
            population: "123,456",
            compactPopulation: "123K",
            outline: [[
                CGPoint(x: 0, y: 0.25), CGPoint(x: 0.45, y: 0), CGPoint(x: 1, y: 0.2),
                CGPoint(x: 0.85, y: 0.75), CGPoint(x: 0.3, y: 0.8)
            ]],
            outlineSize: CGSize(width: 1, height: 0.8),
            confirmedAt: Date()
        )
    )
}
