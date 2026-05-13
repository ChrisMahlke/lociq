//
//  DirectCensusZipDemographicsClient.swift
//  Lociq
//
//  Coordinates Census geocoding, ACS demographics, and TIGER city boundaries.
//

import Foundation

final class DirectCensusZipDemographicsClient: @unchecked Sendable {
    private let geocoderClient: CensusGeocoderClient
    private let boundaryClient: TIGERBoundaryClient
    private let demographicsClient: ACSDemographicsClient

    nonisolated init(
        censusApiKey: String,
        acsYear: Int = 2024,
        session: URLSession = .shared
    ) {
        let httpClient = CensusHTTPClient(session: session)
        geocoderClient = CensusGeocoderClient(httpClient: httpClient)
        boundaryClient = TIGERBoundaryClient(httpClient: httpClient)
        demographicsClient = ACSDemographicsClient(
            censusApiKey: censusApiKey,
            acsYear: acsYear,
            httpClient: httpClient
        )
    }

    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedPlaceProfile {
        let geography = try await geocoderClient.fetchGeographiesFromCoordinate(
            latitude: latitude,
            longitude: longitude
        )
        let zipDemographics = try await demographicsClient.fetchDemographics(zcta: geography.zcta)
        let zipBundle = ZipLookupResult(
            zcta: geography.zcta,
            county: geography.county,
            place: geography.place,
            demographics: zipDemographics
        )

        async let cityBoundaryTask = boundaryClient.fetchPlaceBoundary(place: geography.place)
        async let placeDemographicsTask = fetchPlaceDemographics(place: geography.place)

        return await ResolvedPlaceProfile(
            zipBundle: zipBundle,
            boundaries: NeighborhoodBoundarySet(city: cityBoundaryTask),
            scaleDemographics: ScaleDemographicsBundle(
                place: try? placeDemographicsTask,
                zip: zipDemographics
            )
        )
    }

    private func fetchPlaceDemographics(place: PlaceInfo?) async throws -> Demographics {
        guard let place else {
            throw CensusZipDemographicsService.ServiceError.noDemographicsFound
        }

        return try await demographicsClient.fetchDemographics(place: place)
    }
}
