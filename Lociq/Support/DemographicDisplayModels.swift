//
//  DemographicDisplayModels.swift
//  Lociq
//
//  Defines compact display models used by the demographic UI.
//

import Foundation

struct DemographicMetric: Identifiable, Codable, Sendable {
    var id: String { title }
    let title: String
    let primaryValue: String
    let detail: String
}

struct DemographicDetailSection: Identifiable, Codable, Sendable {
    var id: String { title }
    let title: String
    let rows: [DemographicDetailRow]
}

struct DemographicDetailRow: Identifiable, Codable, Sendable {
    var id: String { label }
    let label: String
    let value: String
    let progress: Double?

    /// Creates one details row with an optional progress-line value.
    init(label: String, value: String, progress: Double? = nil) {
        self.label = label
        self.value = value
        self.progress = progress
    }
}
