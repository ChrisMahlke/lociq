//
//  CityProfileSnapshot.swift
//  Lociq
//
//  Builds the UI-ready city demographic snapshot from loaded profile data.
//

import Foundation

struct DemographicSnapshot: Codable, Sendable {
    enum LocationStatus {
        case censusKeyMissing
        case cityUnavailable
        case demographicsUnavailable
        case boundaryUnavailable
        case networkUnavailable
        case timedOut
        case serviceUnavailable

        var fallbackMarket: String {
            switch self {
            case .censusKeyMissing:
                return "CENSUS KEY"
            case .cityUnavailable:
                return "CITY"
            case .demographicsUnavailable:
                return "DEMOGRAPHICS"
            case .boundaryUnavailable:
                return "BOUNDARY"
            case .networkUnavailable:
                return "NETWORK"
            case .timedOut:
                return "TIMEOUT"
            case .serviceUnavailable:
                return "ACS"
            }
        }
    }

    let market: String
    let dateLabel: String
    let cadence: String
    let mode: String
    let confidence: Double
    let hasDemographicData: Bool
    let metrics: [DemographicMetric]
    let detailSections: [DemographicDetailSection]

    static let placeholder = DemographicSnapshot(
        market: "LOCATION",
        dateLabel: "ENABLE ACCESS",
        cadence: "DEMOGRAPHICS PAUSED",
        mode: "LOCATION",
        confidence: 0,
        hasDemographicData: false,
        metrics: [
            DemographicMetric(
                title: "ACCESS",
                primaryValue: "--",
                detail: "ENABLE LOCATION"
            )
        ],
        detailSections: []
    )

    static let loading = DemographicSnapshot.status(
        market: "LOCATING",
        dateLabel: "ACS",
        cadence: "READING AREA",
        mode: "LOADING"
    )

    /// Builds the minimal snapshot shown when a profile cannot be fully loaded.
    static func status(for status: LocationStatus, market: String) -> DemographicSnapshot {
        switch status {
        case .censusKeyMissing:
            return DemographicSnapshot.status(
                market: market,
                dateLabel: "CENSUS KEY",
                cadence: "ADD API KEY",
                mode: "NO KEY"
            )
        case .cityUnavailable:
            return DemographicSnapshot.status(
                market: market,
                dateLabel: "CITY",
                cadence: "NOT FOUND",
                mode: "NO CITY"
            )
        case .demographicsUnavailable:
            return DemographicSnapshot.status(
                market: market,
                dateLabel: "ACS",
                cadence: "NO DATA",
                mode: "NO DATA"
            )
        case .boundaryUnavailable:
            return DemographicSnapshot.status(
                market: market,
                dateLabel: "BOUNDARY",
                cadence: "NO OUTLINE",
                mode: "NO BOUNDARY"
            )
        case .networkUnavailable:
            return DemographicSnapshot.status(
                market: market,
                dateLabel: "NETWORK",
                cadence: "TRY AGAIN",
                mode: "OFFLINE"
            )
        case .timedOut:
            return DemographicSnapshot.status(
                market: market,
                dateLabel: "TIMEOUT",
                cadence: "TRY AGAIN",
                mode: "SLOW ACS"
            )
        case .serviceUnavailable:
            return DemographicSnapshot.status(
                market: market,
                dateLabel: "ACS",
                cadence: "TRY AGAIN LATER",
                mode: "OFFLINE"
            )
        }
    }

    /// Builds a status snapshot with one compact metric row.
    private static func status(
        market: String,
        dateLabel: String,
        cadence: String,
        mode: String
    ) -> DemographicSnapshot {
        DemographicSnapshot(
            market: market,
            dateLabel: dateLabel,
            cadence: cadence,
            mode: mode,
            confidence: 0,
            hasDemographicData: false,
            metrics: [
                DemographicMetric(title: "CITY PROFILE", primaryValue: "--", detail: cadence)
            ],
            detailSections: []
        )
    }

    /// Returns a copy of the snapshot with a different date/status label.
    func replacingDateLabel(_ dateLabel: String) -> DemographicSnapshot {
        DemographicSnapshot(
            market: market,
            dateLabel: dateLabel,
            cadence: cadence,
            mode: mode,
            confidence: confidence,
            hasDemographicData: hasDemographicData,
            metrics: metrics,
            detailSections: detailSections
        )
    }

    var shareText: String? {
        guard hasDemographicData else { return nil }
        let metricLines = metrics.map { "\($0.title): \($0.primaryValue)" }
        return ([market] + metricLines).joined(separator: "\n")
    }
}

extension DemographicSnapshot {
    /// Creates the visible home and details content from a resolved city profile.
    init(profile: ResolvedCityProfile, demographics: Demographics) {
        let households = DemographicValueFormatter.households(from: demographics)
        let ownerPct = DemographicValueFormatter.percent(demographics.housing.ownerOccupiedPct)

        self.init(
            market: DemographicValueFormatter.title(from: profile, demographics: demographics).uppercased(),
            dateLabel: "",
            cadence: "",
            mode: "DEMOGRAPHICS",
            confidence: 0.84,
            hasDemographicData: true,
            metrics: [
                DemographicMetric(
                    title: "POPULATION",
                    primaryValue: DemographicValueFormatter.number(demographics.population.total),
                    detail: "MEDIAN AGE \(DemographicValueFormatter.decimal(demographics.age.median))"
                ),
                DemographicMetric(
                    title: "HOUSEHOLDS",
                    primaryValue: DemographicValueFormatter.number(households),
                    detail: "OCCUPIED HOMES"
                ),
                DemographicMetric(
                    title: "INCOME",
                    primaryValue: DemographicValueFormatter.currency(demographics.income.medianHousehold),
                    detail: "MEDIAN HOUSEHOLD"
                ),
                DemographicMetric(
                    title: "RENTERS",
                    primaryValue: DemographicValueFormatter.percent(demographics.housing.renterOccupiedPct),
                    detail: "\(ownerPct) OWNER OCCUPIED"
                ),
                DemographicMetric(
                    title: "EDUCATION",
                    primaryValue: DemographicValueFormatter.percent(demographics.education.bachelorsOrHigherPct),
                    detail: "BACHELOR'S OR HIGHER"
                )
            ],
            detailSections: [
                DemographicDetailSection(
                    title: "AGE",
                    rows: [
                        DemographicDetailRow(label: "UNDER 18", value: DemographicValueFormatter.percent(demographics.age.under18Pct)),
                        DemographicDetailRow(label: "18 TO 34", value: DemographicValueFormatter.percent(demographics.age.age18To34Pct)),
                        DemographicDetailRow(label: "35 TO 64", value: DemographicValueFormatter.percent(demographics.age.age35To64Pct)),
                        DemographicDetailRow(label: "65 PLUS", value: DemographicValueFormatter.percent(demographics.age.age65PlusPct))
                    ]
                ),
                DemographicDetailSection(
                    title: "HOUSING",
                    rows: [
                        DemographicDetailRow(label: "MEDIAN RENT", value: DemographicValueFormatter.currency(demographics.housing.medianGrossRent)),
                        DemographicDetailRow(label: "MEDIAN VALUE", value: DemographicValueFormatter.currency(demographics.housing.medianHomeValue)),
                        DemographicDetailRow(label: "VACANCY", value: DemographicValueFormatter.percent(demographics.housing.vacancyRatePct))
                    ]
                ),
                DemographicDetailSection(
                    title: "MOBILITY",
                    rows: [
                        DemographicDetailRow(label: "TRANSIT", value: DemographicValueFormatter.percent(demographics.mobility.transitCommutersPct)),
                        DemographicDetailRow(label: "REMOTE WORK", value: DemographicValueFormatter.percent(demographics.mobility.workersWfhPct)),
                        DemographicDetailRow(label: "AVG COMMUTE", value: DemographicValueFormatter.minutes(demographics.mobility.averageCommuteMinutes))
                    ]
                )
            ]
        )
    }
}
