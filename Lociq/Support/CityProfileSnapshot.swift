//
//  CityProfileSnapshot.swift
//  Lociq
//
//  Builds the UI-ready city demographic snapshot from loaded profile data.
//
//  The snapshot is the view-facing model. It contains display strings, not raw
//  ACS values. Keeping formatting here makes SwiftUI views small and keeps
//  Census data interpretation out of the rendering layer.
//

import Foundation

/// Complete display payload for the home and details demographic views.
///
/// `DemographicSnapshot` is cacheable because it is fully detached from raw
/// service models. A cached snapshot can render immediately while live Census
/// data refreshes in the background.
struct DemographicSnapshot: Codable, Sendable {
    /// Minimal status categories used when real demographic content cannot be shown.
    ///
    /// These statuses intentionally map to short labels because the UI has very
    /// little text surface for failures.
    enum LocationStatus {
        case censusKeyMissing
        case cityUnavailable
        case demographicsUnavailable
        case boundaryUnavailable
        case networkUnavailable
        case timedOut
        case serviceUnavailable

        /// Short heading used when no resolved city label exists.
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

    /// Main place title shown at the top of the UI.
    let market: String

    /// Secondary status/date label below the place title.
    let dateLabel: String

    /// Small descriptive cadence or state string used by failure snapshots.
    let cadence: String

    /// Internal display mode label used by status snapshots.
    let mode: String

    /// Confidence/progress value used by the bottom line.
    let confidence: Double

    /// Indicates whether metrics represent real ACS demographic values.
    let hasDemographicData: Bool

    /// Summary metrics shown on the primary view.
    let metrics: [DemographicMetric]

    /// Detail sections shown after the bottom action toggles views.
    let detailSections: [DemographicDetailSection]

    /// Placeholder shown when location access is not yet available.
    ///
    /// The placeholder intentionally avoids demographic-shaped values so users
    /// do not mistake it for real data.
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

    /// Initial loading snapshot used before a displayable state exists.
    static let loading = DemographicSnapshot.status(
        market: "LOCATING",
        dateLabel: "ACS",
        cadence: "READING AREA",
        mode: "LOADING"
    )

    /// Builds the minimal snapshot shown when a profile cannot be fully loaded.
    ///
    /// - Parameters:
    ///   - status: Normalized location or service state.
    ///   - market: Short heading to display, usually a city name or fallback label.
    /// - Returns: A non-demographic snapshot that remains visually consistent
    ///   with the rest of the app.
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
    ///
    /// Status snapshots have `hasDemographicData == false`, which prevents the
    /// detail view and boundary-only UI from implying real metrics exist.
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
    ///
    /// This is used when stale cached data is shown without surfacing a visible
    /// "cached" label in the minimal UI.
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

    /// Plain text summary suitable for the share sheet.
    ///
    /// Share text is available only for real demographic data. Failure and
    /// permission states return `nil` so the UI does not expose misleading share
    /// actions.
    var shareText: String? {
        guard hasDemographicData else { return nil }
        let metricLines = metrics.map { "\($0.title): \($0.primaryValue)" }
        return ([market] + metricLines).joined(separator: "\n")
    }
}

extension DemographicSnapshot {
    /// Creates the visible home and details content from a resolved city profile.
    ///
    /// This initializer is where domain values become display strings. It keeps
    /// the summary view focused on a small set of metrics and the detail view
    /// grouped into age, housing, and mobility sections.
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
