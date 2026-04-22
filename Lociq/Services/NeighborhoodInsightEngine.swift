//
//  NeighborhoodInsightEngine.swift
//  Lociq
//
//  Derived neighborhood insights and boundary metric helpers.
//

import CoreLocation
import Foundation

enum InsightEngine {
    static func makeInsights(
        zcta: String,
        county: CountyInfo?,
        tract: TractInfo?,
        isIncorporatedPlace: Bool,
        boundaryMetrics: BoundaryMetrics?,
        demographics: Demographics
    ) -> [Insight] {
        var insights: [Insight] = []
        var housingDetails: [String] = []
        var housingSeverity: Insight.Severity = .neutral

        if let homeValue = demographics.medianHomeValue {
            let qualifier = homeValue >= 1_000_000 ? AppStrings.Insight.highQualifier : ""
            housingDetails.append(
                AppStrings.Formats.housingSnapshotHomeValue(
                    formatCurrency(homeValue),
                    qualifier: qualifier
                )
            )
            if homeValue >= 1_000_000 {
                housingSeverity = .caution
            }
        }

        if let rent = demographics.medianGrossRent {
            let qualifier = rent >= 3000 ? AppStrings.Insight.highQualifier : ""
            housingDetails.append(
                AppStrings.Formats.housingSnapshotRent(
                    formatCurrency(rent),
                    qualifier: qualifier
                )
            )
            if rent >= 3000 {
                housingSeverity = .caution
            }
        }

        if let ownerPct = demographics.ownerOccupiedPct,
           let renterPct = demographics.renterOccupiedPct {
            housingDetails.append(
                AppStrings.Formats.ownerOccupied(
                    formatPct(ownerPct),
                    renter: formatPct(renterPct)
                )
            )
            if housingSeverity != .caution, ownerPct >= 60 {
                housingSeverity = .positive
            }
        }

        if let ownerPct = demographics.ownerOccupiedPct,
           let householdSize = demographics.averageHouseholdSize {
            housingDetails.append(
                AppStrings.Formats.homeownership(
                    formatPct(ownerPct),
                    householdSize: formatNumber(householdSize, decimals: 1)
                )
            )
        }

        if !housingDetails.isEmpty {
            insights.append(
                Insight(
                    category: .housing,
                    severity: housingSeverity,
                    title: AppStrings.Insight.housingSnapshotTitle,
                    detail: housingDetails.joined(separator: ". ") + "."
                )
            )
        }

        if let householdSize = demographics.averageHouseholdSize {
            insights.append(
                Insight(
                    category: .demographics,
                    severity: .neutral,
                    title: AppStrings.Insight.averageHouseholdSizeTitle,
                    detail: AppStrings.Formats.peoplePerHousehold(formatNumber(householdSize, decimals: 2))
                )
            )
        }

        if let workFromHome = demographics.workersWfhPct {
            let severity: Insight.Severity = workFromHome >= 20 ? .positive : .neutral
            let title = workFromHome >= 20
                ? AppStrings.Insight.remoteWorkCommonTitle
                : AppStrings.Insight.remoteWorkLessCommonTitle

            insights.append(
                Insight(
                    category: .mobility,
                    severity: severity,
                    title: title,
                    detail: AppStrings.Formats.workersReportWorkingFromHome(formatPct(workFromHome))
                )
            )
        }

        if let povertyRate = demographics.povertyRatePct {
            let severity: Insight.Severity
            let title: String

            if povertyRate >= 20 {
                severity = .caution
                title = AppStrings.Insight.higherPovertyRateTitle
            } else if povertyRate <= 8 {
                severity = .positive
                title = AppStrings.Insight.lowerPovertyRateTitle
            } else {
                severity = .neutral
                title = AppStrings.Insight.povertyRateTitle
            }

            insights.append(
                Insight(
                    category: .affordability,
                    severity: severity,
                    title: title,
                    detail: AppStrings.Formats.belowPovertyLine(formatPct(povertyRate))
                )
            )
        }

        return insights
    }

    private static func formatCurrency(_ value: Int) -> String {
        NumberFormatting.currencyString(value)
    }

    private static func formatPct(_ value: Double) -> String {
        "\(formatNumber(value, decimals: 0))%"
    }

    private static func formatNumber(_ value: Double, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.locale = .current
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

enum BoundaryAnalyzer {
    private static let earthRadiusMeters = 6_371_008.8

    static func metrics(from featureCollection: GeoJSONFeatureCollection) -> BoundaryMetrics? {
        var allPoints: [(lat: Double, lon: Double)] = []
        var areaM2Total = 0.0
        var perimeterMTotal = 0.0

        for feature in featureCollection.features {
            guard let geometry = feature.geometry else { continue }

            switch geometry {
            case .polygon(let rings):
                if let exterior = rings.first {
                    let points = exterior.compactMap { coordinate -> (Double, Double)? in
                        guard coordinate.count >= 2 else { return nil }
                        return (coordinate[1], coordinate[0])
                    }

                    if points.count >= 3 {
                        allPoints.append(contentsOf: points)
                        areaM2Total += abs(sphericalPolygonArea(points))
                        perimeterMTotal += polylineLength(points, closed: true)
                    }
                }
            case .multiPolygon(let polygons):
                for polygon in polygons {
                    guard let exterior = polygon.first else { continue }

                    let points = exterior.compactMap { coordinate -> (Double, Double)? in
                        guard coordinate.count >= 2 else { return nil }
                        return (coordinate[1], coordinate[0])
                    }

                    if points.count >= 3 {
                        allPoints.append(contentsOf: points)
                        areaM2Total += abs(sphericalPolygonArea(points))
                        perimeterMTotal += polylineLength(points, closed: true)
                    }
                }
            case .other:
                continue
            }
        }

        guard !allPoints.isEmpty else { return nil }

        return BoundaryMetrics(
            centroid: centroidApprox(allPoints),
            bbox: boundingBox(allPoints),
            areaKm2Approx: areaM2Total > 0 ? areaM2Total / 1_000_000.0 : nil,
            perimeterKmApprox: perimeterMTotal > 0 ? perimeterMTotal / 1_000.0 : nil
        )
    }

    private static func boundingBox(_ points: [(lat: Double, lon: Double)]) -> BoundingBox {
        var minLat = Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude

        for point in points {
            minLat = min(minLat, point.lat)
            minLon = min(minLon, point.lon)
            maxLat = max(maxLat, point.lat)
            maxLon = max(maxLon, point.lon)
        }

        return BoundingBox(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
    }

    private static func centroidApprox(_ points: [(lat: Double, lon: Double)]) -> CLLocationCoordinate2D? {
        guard !points.isEmpty else { return nil }

        let sumLat = points.reduce(0.0) { $0 + $1.lat }
        let sumLon = points.reduce(0.0) { $0 + $1.lon }

        return CLLocationCoordinate2D(
            latitude: sumLat / Double(points.count),
            longitude: sumLon / Double(points.count)
        )
    }

    private static func polylineLength(_ points: [(lat: Double, lon: Double)], closed: Bool) -> Double {
        guard points.count >= 2 else { return 0 }

        var total = 0.0
        for index in 1..<points.count {
            total += haversineMeters(points[index - 1], points[index])
        }

        if closed {
            total += haversineMeters(points[points.count - 1], points[0])
        }

        return total
    }

    private static func haversineMeters(_ a: (lat: Double, lon: Double), _ b: (lat: Double, lon: Double)) -> Double {
        let lat1 = a.lat * .pi / 180.0
        let lon1 = a.lon * .pi / 180.0
        let lat2 = b.lat * .pi / 180.0
        let lon2 = b.lon * .pi / 180.0

        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        let sinDLat = sin(dLat / 2)
        let sinDLon = sin(dLon / 2)
        let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
        let c = 2 * atan2(sqrt(h), sqrt(1 - h))

        return earthRadiusMeters * c
    }

    private static func sphericalPolygonArea(_ points: [(lat: Double, lon: Double)]) -> Double {
        guard points.count >= 3 else { return 0 }

        var sum = 0.0
        for index in 0..<points.count {
            let nextIndex = (index + 1) % points.count
            let lat1 = points[index].lat * .pi / 180.0
            let lat2 = points[nextIndex].lat * .pi / 180.0
            let lon1 = points[index].lon * .pi / 180.0
            let lon2 = points[nextIndex].lon * .pi / 180.0

            var deltaLon = lon2 - lon1
            if deltaLon > .pi { deltaLon -= 2 * .pi }
            if deltaLon < -.pi { deltaLon += 2 * .pi }

            sum += deltaLon * (sin(lat1) + sin(lat2))
        }

        return (earthRadiusMeters * earthRadiusMeters) * (sum / 2.0)
    }
}
