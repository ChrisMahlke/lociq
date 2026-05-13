import Foundation

struct DemographicSnapshot: Codable, Sendable {
    enum LocationStatus {
        case censusKeyMissing
        case cityUnavailable
        case demographicsUnavailable
        case boundaryUnavailable
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
        case .serviceUnavailable:
            return DemographicSnapshot.status(
                market: market,
                dateLabel: "ACS",
                cadence: "TRY AGAIN LATER",
                mode: "OFFLINE"
            )
        }
    }

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
}

extension DemographicSnapshot {
    init(profile: ResolvedCityProfile, demographics: Demographics) {
        let households = DemographicValueFormatter.households(from: demographics)
        let ownerPct = DemographicValueFormatter.percent(demographics.ownerOccupiedPct)

        self.init(
            market: DemographicValueFormatter.title(from: profile).uppercased(),
            dateLabel: "",
            cadence: "",
            mode: "DEMOGRAPHICS",
            confidence: 0.84,
            hasDemographicData: true,
            metrics: [
                DemographicMetric(
                    title: "POPULATION",
                    primaryValue: DemographicValueFormatter.number(demographics.population),
                    detail: "MEDIAN AGE \(DemographicValueFormatter.decimal(demographics.medianAge))"
                ),
                DemographicMetric(
                    title: "HOUSEHOLDS",
                    primaryValue: DemographicValueFormatter.number(households),
                    detail: "OCCUPIED HOMES"
                ),
                DemographicMetric(
                    title: "INCOME",
                    primaryValue: DemographicValueFormatter.currency(demographics.medianHouseholdIncome),
                    detail: "MEDIAN HOUSEHOLD"
                ),
                DemographicMetric(
                    title: "RENTERS",
                    primaryValue: DemographicValueFormatter.percent(demographics.renterOccupiedPct),
                    detail: "\(ownerPct) OWNER OCCUPIED"
                ),
                DemographicMetric(
                    title: "EDUCATION",
                    primaryValue: DemographicValueFormatter.percent(demographics.bachelorsOrHigherPct),
                    detail: "BACHELOR'S OR HIGHER"
                )
            ],
            detailSections: [
                DemographicDetailSection(
                    title: "AGE",
                    rows: [
                        DemographicDetailRow(label: "UNDER 18", value: DemographicValueFormatter.percent(demographics.under18Pct)),
                        DemographicDetailRow(label: "18 TO 34", value: DemographicValueFormatter.percent(demographics.age18To34Pct)),
                        DemographicDetailRow(label: "35 TO 64", value: DemographicValueFormatter.percent(demographics.age35To64Pct)),
                        DemographicDetailRow(label: "65 PLUS", value: DemographicValueFormatter.percent(demographics.age65PlusPct))
                    ]
                ),
                DemographicDetailSection(
                    title: "HOUSING",
                    rows: [
                        DemographicDetailRow(label: "MEDIAN RENT", value: DemographicValueFormatter.currency(demographics.medianGrossRent)),
                        DemographicDetailRow(label: "MEDIAN VALUE", value: DemographicValueFormatter.currency(demographics.medianHomeValue)),
                        DemographicDetailRow(label: "VACANCY", value: DemographicValueFormatter.percent(demographics.vacancyRatePct))
                    ]
                ),
                DemographicDetailSection(
                    title: "MOBILITY",
                    rows: [
                        DemographicDetailRow(label: "TRANSIT", value: DemographicValueFormatter.percent(demographics.transitCommutersPct)),
                        DemographicDetailRow(label: "REMOTE WORK", value: DemographicValueFormatter.percent(demographics.workersWfhPct)),
                        DemographicDetailRow(label: "AVG COMMUTE", value: DemographicValueFormatter.minutes(demographics.averageCommuteMinutes))
                    ]
                )
            ]
        )
    }
}

enum DemographicValueFormatter {
    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func title(from profile: ResolvedCityProfile) -> String {
        title(from: profile.geography)
    }

    static func title(from geography: CensusGeographiesBundle) -> String {
        if let placeName = geography.place?.name, !placeName.isEmpty {
            return cleanGeographyName(placeName)
        }
        if let countyName = geography.county?.name, !countyName.isEmpty {
            return cleanGeographyName(countyName)
        }
        return "CITY"
    }

    static func title(from geography: CityGeographyProfile) -> String {
        if let placeName = geography.place?.name, !placeName.isEmpty {
            return cleanGeographyName(placeName)
        }
        if let countyName = geography.county?.name, !countyName.isEmpty {
            return cleanGeographyName(countyName)
        }
        return "CITY"
    }

    static func cityTitle(from geography: CensusGeographiesBundle) -> String? {
        guard let placeName = geography.place?.name, !placeName.isEmpty else {
            return nil
        }

        return cleanGeographyName(placeName)
    }

    static func households(from demographics: Demographics) -> Int? {
        if let owner = demographics.ownerOccupied, let renter = demographics.renterOccupied {
            return owner + renter
        }
        return demographics.housingUnits
    }

    static func number(_ value: Int?) -> String {
        guard let value else { return "--" }
        return integerFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func currency(_ value: Int?) -> String {
        guard let value, value >= 0 else { return "--" }
        return currencyFormatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    static func decimal(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "--" }
        return String(format: "%.1f", value)
    }

    static func percent(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    static func minutes(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "--" }
        return "\(Int(value.rounded())) MIN"
    }

    private static func cleanGeographyName(_ name: String) -> String {
        name
            .replacingOccurrences(of: " city", with: "")
            .replacingOccurrences(of: " town", with: "")
            .replacingOccurrences(of: " CDP", with: "")
            .replacingOccurrences(of: "ZCTA5 ", with: "ZIP ")
            .replacingOccurrences(of: ", United States", with: "")
    }
}

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

    init(label: String, value: String, progress: Double? = nil) {
        self.label = label
        self.value = value
        self.progress = progress
    }
}
