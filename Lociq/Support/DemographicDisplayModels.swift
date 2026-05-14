//
//  DemographicDisplayModels.swift
//  Lociq
//
//  Defines compact display models used by the demographic UI.
//
//  These models are already formatted for presentation. They intentionally use
//  strings instead of numeric ACS values so SwiftUI views do not perform
//  formatting, unit conversion, or missing-value handling.
//

import Foundation

/// One summary metric block on the primary demographic view.
struct DemographicMetric: Identifiable, Codable, Sendable {
    /// Stable SwiftUI identity derived from the metric title.
    var id: String { title }

    /// Uppercase metric label, such as `POPULATION`.
    let title: String

    /// Primary formatted value, such as `118,403` or `$92,000`.
    let primaryValue: String

    /// Secondary formatted context line under the primary value.
    let detail: String
}

/// One grouped section in the details view.
struct DemographicDetailSection: Identifiable, Codable, Sendable {
    /// Stable SwiftUI identity derived from the section title.
    var id: String { title }

    /// Uppercase section label, such as `AGE` or `HOUSING`.
    let title: String

    /// Rows displayed under the section label.
    let rows: [DemographicDetailRow]
}

/// One label/value row in a details section.
struct DemographicDetailRow: Identifiable, Codable, Sendable {
    /// Stable SwiftUI identity derived from the display label.
    var id: String { label }

    /// Uppercase row label.
    let label: String

    /// Already formatted display value.
    let value: String

    /// Optional normalized progress value for subtle line indicators.
    let progress: Double?

    /// Creates one details row with an optional progress-line value.
    init(label: String, value: String, progress: Double? = nil) {
        self.label = label
        self.value = value
        self.progress = progress
    }
}
