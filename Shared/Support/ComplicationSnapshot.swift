//
//  ComplicationSnapshot.swift
//  Lociq
//
//  The small record the Apple Watch app leaves for its complications.
//
//  Complications cannot locate the wearer. The watch app writes this record
//  when it shows where the wearer is, and the complications draw it with the
//  time that was true, so a city is never presented as current. This file has
//  no dependencies on the rest of the app, so the widget extension compiles
//  it alone; `ComplicationSnapshotBuilder.swift` builds records in the app.
//

import CoreGraphics
import Foundation

/// What the watch complications show: where the watch app last found the wearer.
nonisolated struct ComplicationSnapshot: Codable, Equatable, Sendable {
    /// A city with its outline, or a place without city data.
    enum Kind: String, Codable, Sendable {
        /// A Census place with demographics.
        case city

        /// A place without city data, such as outside city limits.
        case message
    }

    /// City or message.
    let kind: Kind

    /// Title, such as `SAN FRANCISCO, CA` or `OUTSIDE CITY LIMITS`.
    let title: String

    /// Title without the state, such as `SAN FRANCISCO`, for inline complications.
    let shortTitle: String

    /// Second line of a message, such as the county; empty for cities.
    let subtitle: String

    /// Population in full, such as `830,235`; `nil` for messages.
    let population: String?

    /// Population in few characters, such as `830K`; `nil` for messages.
    let compactPopulation: String?

    /// City outline rings in unit space (the longer side is 1), simplified
    /// for complication sizes and drawn with the even-odd rule. Never the
    /// wearer's position.
    let outline: [[CGPoint]]

    /// Size of the unit-space outline.
    let outlineSize: CGSize

    /// When the watch app showed this as where the wearer was.
    let confirmedAt: Date

    /// True when the record was confirmed on the same day as `date`.
    func isConfirmed(onSameDayAs date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(confirmedAt, inSameDayAs: date)
    }

    /// When the record was true: the time that day, otherwise the date,
    /// such as `AS OF 9:41 AM` or `AS OF SEP 27`.
    func asOfLabel(now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "AS OF " + Self.shortDate(confirmedAt, now: now, calendar: calendar, locale: locale)
    }

    /// The time on the same day as `now`, otherwise the month and day, uppercased.
    static func shortDate(_ date: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        var style: Date.FormatStyle = calendar.isDate(date, inSameDayAs: now)
            ? .dateTime.hour().minute()
            : .dateTime.month(.abbreviated).day()
        style.locale = locale
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return date.formatted(style).uppercased()
    }
}

/// Reads and writes the complication record in the App Group container that
/// the watch app and its complications share.
///
/// Without the App Group (for example on iPhone) there is no container: loads
/// return `nil` and saves do nothing.
nonisolated struct ComplicationSnapshotStore: Sendable {
    /// App Group shared by the Apple Watch app and its complications.
    static let appGroup = "group.io.chrismahlke.lociq"

    /// Record file name inside the container.
    static let fileName = "complication.json"

    /// Directory that holds the record, when available.
    let directoryURL: URL?

    /// Creates a store.
    ///
    /// - Parameter directory: Directory for the record. Defaults to the App
    ///   Group container's `Library/Application Support`.
    init(directory: URL? = nil) {
        directoryURL = directory ?? FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)?
            .appendingPathComponent("Library/Application Support", isDirectory: true)
    }

    /// The saved record, if any.
    func load() -> ComplicationSnapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(ComplicationSnapshot.self, from: data)
    }

    /// Writes a record atomically.
    ///
    /// - Returns: True when the record was written.
    @discardableResult
    func save(_ snapshot: ComplicationSnapshot) -> Bool {
        guard let directoryURL, let fileURL else { return false }
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: fileURL, options: [.atomic])
            return true
        } catch {
            return false
        }
    }

    private var fileURL: URL? {
        directoryURL?.appendingPathComponent(Self.fileName, isDirectory: false)
    }
}
