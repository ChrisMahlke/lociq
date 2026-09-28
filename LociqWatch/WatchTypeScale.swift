//
//  WatchTypeScale.swift
//  LociqWatch
//
//  Defines the Apple Watch typography.
//
//  The watch uses the same rounded, light, uppercase vocabulary as the iPhone
//  app, built on text styles so it follows the watch's text size setting.
//

import SwiftUI

/// Typography for the watch app.
enum WatchTypeScale {
    /// City name on the place page.
    static let city = Font.system(.title3, design: .rounded).weight(.light)

    /// The message title in permission and failure states.
    static let messageTitle = Font.system(.headline, design: .rounded).weight(.regular)

    /// Population, one step above the other values.
    static let primaryValue = Font.system(.title2, design: .rounded).weight(.light)

    /// Summary metric values.
    static let value = Font.system(.title3, design: .rounded).weight(.light)

    /// Summary metric labels such as `POPULATION`.
    static let label = Font.system(.footnote, design: .rounded)

    /// Metric detail lines, details row labels, and section titles.
    static let detail = Font.system(.caption2, design: .rounded)

    /// Details row values.
    static let detailValue = Font.system(.body, design: .rounded).weight(.light)

    /// Status lines under the city and the loading stage line.
    static let status = Font.system(.caption2, design: .rounded).weight(.medium)
}
