//
//  CityProfileSnapshot.swift
//  Lociq
//
//  Builds the UI-ready city demographic snapshot from loaded profile data.
//
//  The snapshot is the view-facing model. It contains display strings plus the
//  typed values views need for behavior. Keeping formatting here makes SwiftUI
//  views small and keeps Census data interpretation out of the rendering layer.
//
//  Persisted with cached profiles (`lociq.lastCityProfile.v1`): add optional
//  fields only, and keep every existing key readable. `LociqTests` pins a
//  payload written by an earlier build.
//

import Foundation

/// Complete display payload for the home and details demographic views.
///
/// `DemographicSnapshot` is cacheable because it is fully detached from raw
/// service models. A cached snapshot can render immediately while live Census
/// data refreshes in the background.
nonisolated struct DemographicSnapshot: Codable, Sendable {
    /// Main place title shown at the top of the UI.
    let market: String

    /// Secondary status line below the place title. Empty when there is nothing to say.
    let statusLine: String

    /// Indicates whether metrics represent real ACS demographic values.
    let hasDemographicData: Bool

    /// Summary metrics shown on the primary view.
    let metrics: [DemographicMetric]

    /// Detail sections shown after the bottom action toggles views.
    let detailSections: [DemographicDetailSection]

    /// People per square mile of land, computed at load time. `nil` in older caches.
    let densityPerSquareMile: Double?

    /// Data vintage identifier, such as `acs2024`. `nil` in older caches.
    let dataVintage: String?

    private enum CodingKeys: String, CodingKey {
        case market
        case statusLine = "dateLabel"
        case hasDemographicData
        case metrics
        case detailSections
        case densityPerSquareMile
        case dataVintage
    }

    /// Creates a snapshot.
    init(
        market: String,
        statusLine: String,
        hasDemographicData: Bool,
        metrics: [DemographicMetric],
        detailSections: [DemographicDetailSection],
        densityPerSquareMile: Double? = nil,
        dataVintage: String? = nil
    ) {
        self.market = market
        self.statusLine = statusLine
        self.hasDemographicData = hasDemographicData
        self.metrics = metrics
        self.detailSections = detailSections
        self.densityPerSquareMile = densityPerSquareMile
        self.dataVintage = dataVintage
    }

    /// Returns a copy of the snapshot with a different status line.
    func withStatus(_ statusLine: String) -> DemographicSnapshot {
        DemographicSnapshot(
            market: market,
            statusLine: statusLine,
            hasDemographicData: hasDemographicData,
            metrics: metrics,
            detailSections: detailSections,
            densityPerSquareMile: densityPerSquareMile,
            dataVintage: dataVintage
        )
    }

    /// The population metric's count, when the snapshot records it.
    var populationCount: Int? {
        metrics.first { $0.resolvedKind == .population }?.count
    }

    /// True for places small enough that ACS estimates carry wide margins of error.
    var isSmallArea: Bool {
        guard let populationCount else { return false }
        return populationCount < 5_000
    }

    /// Plain text summary suitable for the share sheet.
    ///
    /// Share text is available only for real demographic data. Failure and
    /// permission states return `nil` so the UI does not expose misleading share
    /// actions. Coordinates are never shared.
    var shareText: String? {
        guard hasDemographicData else { return nil }
        let source = CensusDataVintage(identifier: dataVintage)?.shareSourceLabel
            ?? "U.S. Census Bureau ACS 5-year estimates"
        var lines = ["LOC IQ · CITY SNAPSHOT", market, source]
        lines += metrics.map { metric in
            metric.detail.isEmpty
                ? "\(metric.title): \(metric.primaryValue)"
                : "\(metric.title): \(metric.primaryValue) — \(metric.detail)"
        }
        if let densityPerSquareMile {
            lines.append("DENSITY: \(CityDensityCalculator.formatted(densityPerSquareMile))")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Non-data states

nonisolated extension DemographicSnapshot {
    /// Builds a snapshot for a state without demographic data.
    ///
    /// These snapshots have `hasDemographicData == false`, which keeps the
    /// details view, boundary, and share action from implying data exists.
    static func message(title: String, status: String) -> DemographicSnapshot {
        DemographicSnapshot(
            market: title,
            statusLine: status,
            hasDemographicData: false,
            metrics: [],
            detailSections: []
        )
    }

    /// First-run state before the user decides on location access. The header is hidden.
    static let permissionPrompt = message(title: "", status: "")

    /// Initial loading snapshot used before a displayable state exists.
    static let loading = message(title: "LOCATING", status: "")

    /// Location access was denied, or Location Services are off.
    static let locationDenied = message(title: "LOCATION OFF", status: "ALLOW IN SETTINGS")

    /// Location access is restricted (for example by Screen Time) and cannot be changed by the user.
    static let locationRestricted = message(title: "LOCATION RESTRICTED", status: "ON THIS DEVICE")

    /// Location is authorized, but no fix arrived after the bounded attempts.
    static let locationNotFound = message(title: "LOCATION UNAVAILABLE", status: "CAN'T FIND YOUR LOCATION")

    /// Builds the snapshot for a profile that could not be loaded.
    ///
    /// Each cause gets a heading and a different plain-language line. The city
    /// is used as the heading when it is known. A county never appears in the
    /// city position; outside every place, it is the explanatory line.
    ///
    /// - Parameters:
    ///   - failure: Normalized failure category.
    ///   - placeTitle: Place display title, when the geocoder resolved one.
    ///   - countyTitle: County display title, used only outside city limits.
    static func unavailable(
        _ failure: CityProfileLoadFailure,
        placeTitle: String? = nil,
        countyTitle: String? = nil
    ) -> DemographicSnapshot {
        let place = placeTitle?.uppercased()
        switch failure {
        case .networkUnavailable:
            return message(title: place ?? "OFFLINE", status: "CHECK CONNECTION")
        case .timedOut:
            return message(title: place ?? "NO RESPONSE", status: "CENSUS SERVICE TIMED OUT")
        case .serviceUnavailable:
            return message(title: place ?? "CENSUS SERVICE", status: "TEMPORARILY UNAVAILABLE")
        case .cityUnavailable:
            return message(title: "OUTSIDE CITY LIMITS", status: countyTitle?.uppercased() ?? "NO CENSUS PLACE HERE")
        case .outsideCoverage:
            return message(title: "OUTSIDE U.S. COVERAGE", status: "CITY DATA IS U.S.-ONLY")
        case .demographicsUnavailable:
            return message(title: place ?? "CITY PROFILE", status: "NO CENSUS ESTIMATES FOR THIS PLACE YET")
        case .censusKeyMissing:
            return message(title: place ?? "CENSUS DATA", status: "DATA SERVICE UNAVAILABLE")
        case .boundaryUnavailable:
            return message(title: place ?? "CITY PROFILE", status: "OUTLINE UNAVAILABLE")
        }
    }
}

// MARK: - Loaded profiles

nonisolated extension DemographicSnapshot {
    /// Creates the visible home and details content from a resolved city profile.
    ///
    /// This initializer is where domain values become display strings. Bars,
    /// density, and the owner/renter split are derived from the same rounded
    /// values the text shows, so text and graphics can never disagree.
    init(profile: ResolvedCityProfile, demographics: Demographics, vintage: CensusDataVintage = .current) {
        let title: String
        if let place = profile.geography.place {
            title = DemographicValueFormatter.placeTitle(for: place)
        } else {
            title = DemographicValueFormatter.cleanGeographyName(demographics.name)
        }
        let households = DemographicValueFormatter.households(from: demographics)
        let ownerShare = DemographicValueFormatter.wholePercent(demographics.housing.ownerOccupiedPct)
        let educationShare = DemographicValueFormatter.wholePercent(demographics.education.bachelorsOrHigherPct)

        self.init(
            market: title.uppercased(),
            statusLine: "",
            hasDemographicData: true,
            metrics: [
                DemographicMetric(
                    title: "POPULATION",
                    primaryValue: DemographicValueFormatter.number(demographics.population.total),
                    detail: "MEDIAN AGE \(DemographicValueFormatter.decimal(demographics.age.median))",
                    kind: .population,
                    count: demographics.population.total
                ),
                DemographicMetric(
                    title: "INCOME",
                    primaryValue: DemographicValueFormatter.currency(
                        demographics.income.medianHousehold,
                        bound: demographics.income.medianHouseholdBound
                    ),
                    detail: "MEDIAN HOUSEHOLD",
                    kind: .income
                ),
                DemographicMetric(
                    title: "HOUSEHOLDS",
                    primaryValue: DemographicValueFormatter.number(households),
                    detail: "OCCUPIED HOMES",
                    kind: .households,
                    count: households
                ),
                DemographicMetric(
                    title: "OWNER OCCUPIED",
                    primaryValue: ownerShare.map { "\($0)%" } ?? "--",
                    detail: ownerShare.map { "\(100 - $0)% RENTERS" } ?? "",
                    kind: .ownerOccupied,
                    fraction: ownerShare.map { Double($0) / 100 }
                ),
                DemographicMetric(
                    title: "EDUCATION",
                    primaryValue: educationShare.map { "\($0)%" } ?? "--",
                    detail: "BACHELOR'S OR HIGHER",
                    kind: .education,
                    fraction: educationShare.map { Double($0) / 100 }
                )
            ],
            detailSections: [
                DemographicDetailSection(
                    title: "AGE",
                    rows: [
                        DemographicDetailRow(label: "UNDER 18", value: DemographicValueFormatter.percent(demographics.age.under18Pct), kind: .under18),
                        DemographicDetailRow(label: "18 TO 34", value: DemographicValueFormatter.percent(demographics.age.age18To34Pct), kind: .age18To34),
                        DemographicDetailRow(label: "35 TO 64", value: DemographicValueFormatter.percent(demographics.age.age35To64Pct), kind: .age35To64),
                        DemographicDetailRow(label: "65 PLUS", value: DemographicValueFormatter.percent(demographics.age.age65PlusPct), kind: .age65Plus)
                    ]
                ),
                DemographicDetailSection(
                    title: "HOUSING",
                    rows: [
                        DemographicDetailRow(
                            label: "MEDIAN RENT",
                            value: DemographicValueFormatter.currency(
                                demographics.housing.medianGrossRent,
                                bound: demographics.housing.medianGrossRentBound
                            ),
                            kind: .medianRent
                        ),
                        DemographicDetailRow(
                            label: "MEDIAN VALUE",
                            value: DemographicValueFormatter.currency(
                                demographics.housing.medianHomeValue,
                                bound: demographics.housing.medianHomeValueBound
                            ),
                            kind: .medianValue
                        ),
                        DemographicDetailRow(
                            label: "VACANT UNITS",
                            value: DemographicValueFormatter.percent(demographics.housing.vacancyRatePct),
                            kind: .vacantUnits
                        )
                    ]
                ),
                DemographicDetailSection(
                    title: "MOBILITY",
                    rows: [
                        DemographicDetailRow(label: "TRANSIT", value: DemographicValueFormatter.percent(demographics.mobility.transitCommutersPct), kind: .transit),
                        DemographicDetailRow(label: "REMOTE WORK", value: DemographicValueFormatter.percent(demographics.mobility.workersWfhPct), kind: .remoteWork),
                        DemographicDetailRow(label: "AVG COMMUTE", value: DemographicValueFormatter.minutes(demographics.mobility.averageCommuteMinutes), kind: .averageCommute)
                    ]
                )
            ],
            densityPerSquareMile: CityDensityCalculator.peoplePerSquareMile(
                population: demographics.population.total,
                landAreaSquareMeters: profile.boundarySet.city?.landAreaSquareMeters
            ),
            dataVintage: vintage.identifier
        )
    }

    /// Returns the snapshot with its summary metrics in the current layout.
    ///
    /// Profiles cached by earlier builds can list metrics in another order or
    /// use the retired `RENTERS` metric. They are mapped by kind into today's
    /// order, and a renter share becomes the owner-occupied metric with its
    /// tenure bar, so older caches render exactly like fresh data.
    func normalizedForCurrentLayout() -> DemographicSnapshot {
        guard hasDemographicData else { return self }

        var metricsByKind: [DemographicMetricKind: DemographicMetric] = [:]
        for metric in metrics {
            guard let kind = metric.resolvedKind, metricsByKind[kind] == nil else { continue }
            metricsByKind[kind] = metric
        }
        if metricsByKind[.ownerOccupied] == nil, let renters = metricsByKind[.renters] {
            metricsByKind[.ownerOccupied] = Self.ownerMetric(fromLegacyRenters: renters)
        }

        let ordered = DemographicMetricKind.summaryOrder.compactMap { metricsByKind[$0] }
        guard !ordered.isEmpty else { return self }
        return DemographicSnapshot(
            market: market,
            statusLine: statusLine,
            hasDemographicData: hasDemographicData,
            metrics: ordered,
            detailSections: detailSections,
            densityPerSquareMile: densityPerSquareMile,
            dataVintage: dataVintage
        )
    }

    /// Converts a legacy `RENTERS 26% / 74% OWNER OCCUPIED` metric into the owner metric.
    private static func ownerMetric(fromLegacyRenters renters: DemographicMetric) -> DemographicMetric {
        let ownerFromDetail = renters.detail
            .split(separator: " ")
            .first
            .flatMap { DemographicMetric.wholePercent(in: String($0)) }
        let owner = ownerFromDetail ?? DemographicMetric.wholePercent(in: renters.primaryValue).map { 100 - $0 }
        guard let owner else {
            return DemographicMetric(title: "OWNER OCCUPIED", primaryValue: "--", detail: "", kind: .ownerOccupied)
        }
        return DemographicMetric(
            title: "OWNER OCCUPIED",
            primaryValue: "\(owner)%",
            detail: "\(100 - owner)% RENTERS",
            kind: .ownerOccupied,
            fraction: Double(owner) / 100
        )
    }
}
