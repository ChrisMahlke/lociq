//
//  FirebaseLociqCallableClient.swift
//  Lociq
//
//  Typed wrapper around the shared Firebase callable Census backend.
//

import Foundation
import CoreLocation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

public final class FirebaseLociqCallableClient: @unchecked Sendable {
    static func makeDefaultIfAvailable() -> FirebaseLociqCallableClient? {
        guard LociqFirebaseRuntime.isCallableBackendEnabled else {
            return nil
        }

        #if canImport(FirebaseCore) && canImport(FirebaseFunctions)
        guard FirebaseApp.app() != nil else {
            return nil
        }

        #if canImport(FirebaseAuth)
        guard Auth.auth().currentUser != nil else {
            return nil
        }
        #endif

        return FirebaseLociqCallableClient(region: AppConfig.firebaseFunctionsRegion)
        #else
        return nil
        #endif
    }

    #if canImport(FirebaseFunctions)
    private let functions: Functions

    private init(region: String) {
        self.functions = Functions.functions(region: region)
    }

    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedPlaceProfile {
        let response: PlaceProfileResponse = try await call(
            "getLociqPlaceProfile",
            data: [
                "latitude": latitude,
                "longitude": longitude,
                "locale": Self.currentLocaleIdentifier
            ]
        )

        return response.toDomain()
    }

    func fetchZipBundle(latitude: Double, longitude: Double) async throws -> ZipLookupResult {
        let response: ZipBundleResponse = try await call(
            "getLociqZipBundle",
            data: [
                "latitude": latitude,
                "longitude": longitude,
                "locale": Self.currentLocaleIdentifier
            ]
        )

        return response.toDomain()
    }

    func fetchNeighborhoodBoundaries(
        latitude: Double,
        longitude: Double,
        tractGeoid: String?,
        zcta: String?
    ) async throws -> NeighborhoodBoundarySet {
        var payload: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude
        ]

        if let tractGeoid, !tractGeoid.isEmpty {
            payload["tractGeoid"] = tractGeoid
        }

        if let zcta, !zcta.isEmpty {
            payload["zcta"] = zcta
        }

        let response: NeighborhoodBoundariesResponse = try await call(
            "getLociqNeighborhoodBoundaries",
            data: payload
        )

        return NeighborhoodBoundarySet(
            zip: response.zip,
            tract: response.tract,
            block: response.block
        )
    }

    func fetchDemographics(
        scale: NeighborhoodScale,
        zcta: String,
        tractGeoid: String?,
        latitude: Double,
        longitude: Double
    ) async throws -> Demographics {
        var payload: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "scale": scale == .tract ? "tract" : "zip",
            "zcta": zcta
        ]

        if let tractGeoid, !tractGeoid.isEmpty {
            payload["tractGeoid"] = tractGeoid
        }

        let response: DemographicsResponse = try await call(
            "getLociqDemographics",
            data: payload
        )

        return response.demographics.toDomain()
    }

    func fetchComparisonProfile(
        latitude: Double,
        longitude: Double,
        scale: NeighborhoodScale,
        fallbackTitle: String,
        fallbackSubtitle: String
    ) async throws -> ComparisonProfileResult {
        let response: ComparisonProfileResponse = try await call(
            "getLociqComparison",
            data: [
                "latitude": latitude,
                "longitude": longitude,
                "scale": scale == .tract ? "tract" : "zip",
                "fallbackTitle": fallbackTitle,
                "fallbackSubtitle": fallbackSubtitle
            ]
        )

        return response.toDomain()
    }

    func fetchInsights(demographics: Demographics) async throws -> [Insight] {
        let response: InsightsResponse = try await call(
            "getLociqInsights",
            data: [
                "locale": Self.currentLocaleIdentifier,
                "demographics": demographics.callablePayload
            ]
        )

        return response.insights.map { $0.toDomain() }
    }

    private func call<Response: Decodable>(_ name: String, data: [String: Any]) async throws -> Response {
        let options = HTTPSCallableOptions(requireLimitedUseAppCheckTokens: true)
        let callable = functions.httpsCallable(name, options: options)
        let result = try await callable.call(data)

        guard JSONSerialization.isValidJSONObject(result.data) else {
            throw CensusZipDemographicsService.ServiceError.decodeFailed(
                "Callable \(name) returned a non-JSON payload."
            )
        }

        let payload = try JSONSerialization.data(withJSONObject: result.data)
        return try JSONDecoder().decode(Response.self, from: payload)
    }
    #else
    private init(region: String) {
        fatalError("FirebaseFunctions is unavailable in this build.")
    }

    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedPlaceProfile {
        throw CensusZipDemographicsService.ServiceError.decodeFailed(
            "FirebaseFunctions is unavailable in this build."
        )
    }

    func fetchZipBundle(latitude: Double, longitude: Double) async throws -> ZipLookupResult {
        throw CensusZipDemographicsService.ServiceError.decodeFailed(
            "FirebaseFunctions is unavailable in this build."
        )
    }

    func fetchNeighborhoodBoundaries(
        latitude: Double,
        longitude: Double,
        tractGeoid: String?,
        zcta: String?
    ) async throws -> NeighborhoodBoundarySet {
        throw CensusZipDemographicsService.ServiceError.decodeFailed(
            "FirebaseFunctions is unavailable in this build."
        )
    }

    func fetchDemographics(
        scale: NeighborhoodScale,
        zcta: String,
        tractGeoid: String?,
        latitude: Double,
        longitude: Double
    ) async throws -> Demographics {
        throw CensusZipDemographicsService.ServiceError.decodeFailed(
            "FirebaseFunctions is unavailable in this build."
        )
    }

    func fetchComparisonProfile(
        latitude: Double,
        longitude: Double,
        scale: NeighborhoodScale,
        fallbackTitle: String,
        fallbackSubtitle: String
    ) async throws -> ComparisonProfileResult {
        throw CensusZipDemographicsService.ServiceError.decodeFailed(
            "FirebaseFunctions is unavailable in this build."
        )
    }

    func fetchInsights(demographics: Demographics) async throws -> [Insight] {
        throw CensusZipDemographicsService.ServiceError.decodeFailed(
            "FirebaseFunctions is unavailable in this build."
        )
    }
    #endif

    private static var currentLocaleIdentifier: String {
        Locale.preferredLanguages.first ?? Locale.current.identifier
    }
}

private struct PlaceProfileResponse: Decodable {
    let boundaries: NeighborhoodBoundariesResponse
    let scaleDemographics: ScaleDemographicsResponse
    let zipBundle: ZipBundleResponse

    func toDomain() -> ResolvedPlaceProfile {
        ResolvedPlaceProfile(
            zipBundle: zipBundle.toDomain(),
            boundaries: NeighborhoodBoundarySet(
                zip: boundaries.zip,
                tract: boundaries.tract,
                block: boundaries.block
            ),
            scaleDemographics: scaleDemographics.toDomain()
        )
    }
}

private struct ZipBundleResponse: Decodable {
    let boundary: GeoJSONFeatureCollection
    let boundaryMetrics: BoundaryMetricsResponse?
    let county: CountyInfoResponse?
    let demographics: DemographicsModelResponse
    let insights: [InsightResponse]
    let isIncorporatedPlace: Bool
    let place: PlaceInfoResponse?
    let tract: TractInfoResponse?
    let zcta: String

    func toDomain() -> ZipLookupResult {
        let countyInfo = county?.toDomain()
        let tractInfo = tract?.toDomain()
        let placeInfo = place?.toDomain()
        let boundaryMetricsInfo = boundaryMetrics?.toDomain()
        let demographicsModel = demographics.toDomain()

        return ZipLookupResult(
            zcta: zcta,
            county: countyInfo,
            tract: tractInfo,
            place: placeInfo,
            isIncorporatedPlace: isIncorporatedPlace,
            boundary: boundary,
            boundaryMetrics: boundaryMetricsInfo,
            demographics: demographicsModel,
            insights: insights.isEmpty
                ? InsightEngine.makeInsights(
                    zcta: zcta,
                    county: countyInfo,
                    tract: tractInfo,
                    isIncorporatedPlace: isIncorporatedPlace,
                    boundaryMetrics: boundaryMetricsInfo,
                    demographics: demographicsModel
                )
                : insights.map { $0.toDomain() }
        )
    }
}

private struct NeighborhoodBoundariesResponse: Decodable {
    let block: GeoJSONFeatureCollection?
    let tract: GeoJSONFeatureCollection?
    let zip: GeoJSONFeatureCollection
}

private struct ScaleDemographicsResponse: Decodable {
    let tract: DemographicsModelResponse?
    let zip: DemographicsModelResponse

    func toDomain() -> ScaleDemographicsBundle {
        ScaleDemographicsBundle(
            zip: zip.toDomain(),
            tract: tract?.toDomain()
        )
    }
}

private struct DemographicsResponse: Decodable {
    let demographics: DemographicsModelResponse
    let resolvedScale: String
}

private struct InsightsResponse: Decodable {
    let insights: [InsightResponse]
}

private struct ComparisonProfileResponse: Decodable {
    let demographics: DemographicsModelResponse
    let id: String
    let metricsSource: String
    let subtitle: String
    let title: String

    func toDomain() -> ComparisonProfileResult {
        ComparisonProfileResult(
            id: id,
            title: title,
            subtitle: subtitle,
            demographics: demographics.toDomain(),
            metricsSource: MetricsSource(responseValue: metricsSource)
        )
    }
}

private struct CountyInfoResponse: Decodable {
    let countyFIPS: String?
    let geoid: String?
    let name: String
    let stateFIPS: String?

    func toDomain() -> CountyInfo {
        CountyInfo(name: name, stateFIPS: stateFIPS, countyFIPS: countyFIPS, geoid: geoid)
    }
}

private struct TractInfoResponse: Decodable {
    let countyFIPS: String?
    let geoid: String?
    let name: String?
    let stateFIPS: String?
    let tractCode: String?

    func toDomain() -> TractInfo {
        TractInfo(
            name: name,
            geoid: geoid,
            stateFIPS: stateFIPS,
            countyFIPS: countyFIPS,
            tractCode: tractCode
        )
    }
}

private struct PlaceInfoResponse: Decodable {
    let name: String
    let placeFIPS: String?
    let stateFIPS: String?
    let type: String

    func toDomain() -> PlaceInfo {
        PlaceInfo(
            name: name,
            stateFIPS: stateFIPS,
            placeFIPS: placeFIPS,
            type: PlaceInfo.PlaceType(rawValue: type) ?? .unknown
        )
    }
}

private struct BoundaryMetricsResponse: Decodable {
    struct BoundingBoxResponse: Decodable {
        let maxLat: Double
        let maxLon: Double
        let minLat: Double
        let minLon: Double

        func toDomain() -> BoundingBox {
            BoundingBox(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
        }
    }

    struct CentroidResponse: Decodable {
        let latitude: Double
        let longitude: Double
    }

    let areaKm2Approx: Double?
    let bbox: BoundingBoxResponse?
    let centroid: CentroidResponse?
    let perimeterKmApprox: Double?

    func toDomain() -> BoundaryMetrics {
        BoundaryMetrics(
            centroid: centroid.map {
                .init(latitude: $0.latitude, longitude: $0.longitude)
            },
            bbox: bbox?.toDomain(),
            areaKm2Approx: areaKm2Approx,
            perimeterKmApprox: perimeterKmApprox
        )
    }
}

private struct DemographicsModelResponse: Decodable {
    let asianAlone: Int?
    let averageHouseholdSize: Double?
    let blackAlone: Int?
    let hispanicOrLatino: Int?
    let housingUnits: Int?
    let medianAge: Double?
    let medianGrossRent: Int?
    let medianHomeValue: Int?
    let medianHouseholdIncome: Int?
    let name: String
    let ownerOccupied: Int?
    let ownerOccupiedPct: Double?
    let population: Int?
    let povertyBelow: Int?
    let povertyRatePct: Double?
    let povertyUniverse: Int?
    let renterOccupied: Int?
    let renterOccupiedPct: Double?
    let whiteAlone: Int?
    let workersTotal: Int?
    let workersWfh: Int?
    let workersWfhPct: Double?

    func toDomain() -> Demographics {
        Demographics(
            name: name,
            population: population,
            medianHouseholdIncome: medianHouseholdIncome,
            medianAge: medianAge,
            housingUnits: housingUnits,
            medianHomeValue: medianHomeValue,
            medianGrossRent: medianGrossRent,
            averageHouseholdSize: averageHouseholdSize,
            ownerOccupied: ownerOccupied,
            renterOccupied: renterOccupied,
            ownerOccupiedPct: ownerOccupiedPct,
            renterOccupiedPct: renterOccupiedPct,
            workersTotal: workersTotal,
            workersWfh: workersWfh,
            workersWfhPct: workersWfhPct,
            povertyUniverse: povertyUniverse,
            povertyBelow: povertyBelow,
            povertyRatePct: povertyRatePct,
            whiteAlone: whiteAlone,
            blackAlone: blackAlone,
            asianAlone: asianAlone,
            hispanicOrLatino: hispanicOrLatino
        )
    }
}

private struct InsightResponse: Decodable {
    let category: String
    let detail: String
    let severity: String
    let title: String

    func toDomain() -> Insight {
        Insight(
            category: Insight.Category(rawValue: category) ?? .demographics,
            severity: Insight.Severity(rawValue: severity) ?? .neutral,
            title: title,
            detail: detail
        )
    }
}

private extension MetricsSource {
    init(responseValue: String) {
        switch responseValue {
        case "tract":
            self = .tract
        case "sample":
            self = .sample
        default:
            self = .zcta
        }
    }
}

private extension Demographics {
    var callablePayload: [String: Any] {
        var payload: [String: Any] = ["name": name]

        payload["population"] = population
        payload["medianHouseholdIncome"] = medianHouseholdIncome
        payload["medianAge"] = medianAge
        payload["housingUnits"] = housingUnits
        payload["medianHomeValue"] = medianHomeValue
        payload["medianGrossRent"] = medianGrossRent
        payload["averageHouseholdSize"] = averageHouseholdSize
        payload["ownerOccupied"] = ownerOccupied
        payload["renterOccupied"] = renterOccupied
        payload["ownerOccupiedPct"] = ownerOccupiedPct
        payload["renterOccupiedPct"] = renterOccupiedPct
        payload["workersTotal"] = workersTotal
        payload["workersWfh"] = workersWfh
        payload["workersWfhPct"] = workersWfhPct
        payload["povertyUniverse"] = povertyUniverse
        payload["povertyBelow"] = povertyBelow
        payload["povertyRatePct"] = povertyRatePct
        payload["whiteAlone"] = whiteAlone
        payload["blackAlone"] = blackAlone
        payload["asianAlone"] = asianAlone
        payload["hispanicOrLatino"] = hispanicOrLatino

        return payload
    }
}
