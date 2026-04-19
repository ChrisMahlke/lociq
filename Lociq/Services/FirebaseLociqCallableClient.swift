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

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

public final class FirebaseLociqCallableClient: @unchecked Sendable {
    static func makeDefaultIfAvailable() -> FirebaseLociqCallableClient? {
        guard AppConfig.useFirebaseLociqBackend else {
            return nil
        }

        #if canImport(FirebaseCore) && canImport(FirebaseFunctions)
        guard FirebaseApp.app() != nil else {
            return nil
        }

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

    func fetchZipBundle(latitude: Double, longitude: Double) async throws -> ZipLookupResult {
        let response: ZipBundleResponse = try await call(
            "getLociqZipBundle",
            data: [
                "latitude": latitude,
                "longitude": longitude
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
    #endif
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
        ZipLookupResult(
            zcta: zcta,
            county: county?.toDomain(),
            tract: tract?.toDomain(),
            place: place?.toDomain(),
            isIncorporatedPlace: isIncorporatedPlace,
            boundary: boundary,
            boundaryMetrics: boundaryMetrics?.toDomain(),
            demographics: demographics.toDomain(),
            insights: insights.map { $0.toDomain() }
        )
    }
}

private struct NeighborhoodBoundariesResponse: Decodable {
    let block: GeoJSONFeatureCollection?
    let tract: GeoJSONFeatureCollection?
    let zip: GeoJSONFeatureCollection
}

private struct DemographicsResponse: Decodable {
    let demographics: DemographicsModelResponse
    let resolvedScale: String
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
