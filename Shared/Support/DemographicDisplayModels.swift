//
//  DemographicDisplayModels.swift
//  Lociq
//
//  Defines compact display models used by the demographic UI.
//
//  These models are already formatted for presentation. Views read typed kinds
//  and numeric fractions for behavior (bars, typography, accessibility), and
//  strings only for display. They never compare display strings.
//
//  Persisted with cached profiles: add optional fields only. Profiles cached by
//  earlier builds have no `kind`, `fraction`, or `count`; `resolvedKind` maps
//  their titles instead.
//

import Foundation

/// Identity of a summary metric, independent of its display title.
nonisolated enum DemographicMetricKind: String, Codable, Sendable, CaseIterable {
    case population
    case income
    case households
    case ownerOccupied
    case education

    /// Renter share. Only profiles cached before owner occupancy replaced it use this kind.
    case renters

    /// Maps the titles written by earlier builds to a kind.
    init?(legacyTitle: String) {
        switch legacyTitle {
        case "POPULATION": self = .population
        case "INCOME": self = .income
        case "HOUSEHOLDS": self = .households
        case "OWNER OCCUPIED": self = .ownerOccupied
        case "EDUCATION": self = .education
        case "RENTERS": self = .renters
        default: return nil
        }
    }

    /// Order of the summary metrics on the home view.
    static let summaryOrder: [DemographicMetricKind] = [.population, .income, .households, .ownerOccupied, .education]

    /// True for percentage metrics drawn with a quiet bar.
    var showsBar: Bool {
        self == .ownerOccupied || self == .education
    }

    /// Natural-language name for VoiceOver.
    var spokenName: String {
        switch self {
        case .population: return "Population"
        case .income: return "Median household income"
        case .households: return "Households"
        case .ownerOccupied: return "Owner occupied"
        case .education: return "Bachelor's degree or higher"
        case .renters: return "Renters"
        }
    }
}

/// One summary metric block on the primary demographic view.
nonisolated struct DemographicMetric: Identifiable, Codable, Sendable {
    /// Stable SwiftUI identity derived from the metric kind or title.
    var id: String { resolvedKind?.rawValue ?? title }

    /// Uppercase metric label, such as `POPULATION`.
    let title: String

    /// Primary formatted value, such as `118,403` or `$92,000`.
    let primaryValue: String

    /// Secondary formatted context line under the primary value.
    let detail: String

    /// Typed identity. `nil` in profiles cached by earlier builds.
    let kind: DemographicMetricKind?

    /// Bar fill in `0...1`, derived from the same rounded value the text shows.
    let fraction: Double?

    /// Underlying count for count metrics, such as total population.
    let count: Int?

    /// Creates a summary metric.
    init(
        title: String,
        primaryValue: String,
        detail: String,
        kind: DemographicMetricKind? = nil,
        fraction: Double? = nil,
        count: Int? = nil
    ) {
        self.title = title
        self.primaryValue = primaryValue
        self.detail = detail
        self.kind = kind
        self.fraction = fraction
        self.count = count
    }

    /// Typed identity, falling back to the legacy title for older cached profiles.
    var resolvedKind: DemographicMetricKind? {
        kind ?? DemographicMetricKind(legacyTitle: title)
    }

    /// Bar fill for percentage metrics.
    ///
    /// Older cached profiles have no stored fraction; their whole-number
    /// percentage text is the only source, so it is read once here.
    var barFraction: Double? {
        guard resolvedKind?.showsBar == true else { return nil }
        if let fraction { return min(max(fraction, 0), 1) }
        return Self.wholePercent(in: primaryValue).map { Double($0) / 100 }
    }

    /// A natural-language VoiceOver phrase with the metric's full context.
    var accessibilitySummary: String {
        let name = resolvedKind?.spokenName ?? title.capitalized
        let value = primaryValue == "--" ? "unavailable" : primaryValue
        return [name, value, detail.lowercased()]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// Reads a whole-number percentage such as `59%` from legacy display text.
    static func wholePercent(in text: String) -> Int? {
        guard text.hasSuffix("%"), let value = Int(text.dropLast()), (0...100).contains(value) else { return nil }
        return value
    }
}

/// One grouped section in the details view.
nonisolated struct DemographicDetailSection: Identifiable, Codable, Sendable {
    /// Stable SwiftUI identity derived from the section title.
    var id: String { title }

    /// Uppercase section label, such as `AGE` or `HOUSING`.
    let title: String

    /// Rows displayed under the section label.
    let rows: [DemographicDetailRow]
}

/// Identity of a details row, independent of its display label.
nonisolated enum DemographicDetailKind: String, Codable, Sendable {
    case under18
    case age18To34
    case age35To64
    case age65Plus
    case medianRent
    case medianValue
    case vacantUnits
    case transit
    case remoteWork
    case averageCommute

    /// Maps the labels written by earlier builds to a kind.
    init?(legacyLabel: String) {
        switch legacyLabel {
        case "UNDER 18": self = .under18
        case "18 TO 34": self = .age18To34
        case "35 TO 64": self = .age35To64
        case "65 PLUS": self = .age65Plus
        case "MEDIAN RENT": self = .medianRent
        case "MEDIAN VALUE": self = .medianValue
        case "VACANCY", "VACANT UNITS": self = .vacantUnits
        case "TRANSIT": self = .transit
        case "REMOTE WORK": self = .remoteWork
        case "AVG COMMUTE": self = .averageCommute
        default: return nil
        }
    }

    /// True for age bands, whose labels mix small words with larger numbers.
    var isAgeBand: Bool {
        switch self {
        case .under18, .age18To34, .age35To64, .age65Plus: return true
        default: return false
        }
    }

    /// Natural-language label for VoiceOver.
    var spokenLabel: String {
        switch self {
        case .under18: return "Under 18"
        case .age18To34: return "Age 18 to 34"
        case .age35To64: return "Age 35 to 64"
        case .age65Plus: return "Age 65 and over"
        case .medianRent: return "Median gross rent"
        case .medianValue: return "Median home value"
        case .vacantUnits: return "Vacant housing units, including seasonal homes"
        case .transit: return "Commute by public transit"
        case .remoteWork: return "Work from home"
        case .averageCommute: return "Average commute"
        }
    }
}

/// One label/value row in a details section.
nonisolated struct DemographicDetailRow: Identifiable, Codable, Sendable {
    /// Stable SwiftUI identity derived from the kind or display label.
    var id: String { resolvedKind?.rawValue ?? label }

    /// Uppercase row label.
    let label: String

    /// Already formatted display value.
    let value: String

    /// Typed identity. `nil` in profiles cached by earlier builds.
    let kind: DemographicDetailKind?

    /// Creates one details row.
    init(label: String, value: String, kind: DemographicDetailKind? = nil) {
        self.label = label
        self.value = value
        self.kind = kind
    }

    /// Typed identity, falling back to the legacy label for older cached profiles.
    var resolvedKind: DemographicDetailKind? {
        kind ?? DemographicDetailKind(legacyLabel: label)
    }

    /// Row label for VoiceOver.
    var accessibilityLabel: String {
        resolvedKind?.spokenLabel ?? label.capitalized
    }

    /// Row value for VoiceOver, with abbreviations spelled out.
    var accessibilityValue: String {
        if value == "--" { return "unavailable" }
        if value.hasSuffix(" MIN") { return value.replacingOccurrences(of: " MIN", with: " minutes") }
        return value
    }
}
